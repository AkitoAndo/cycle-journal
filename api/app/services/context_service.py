"""Coach context memory helpers."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from google.cloud.firestore import AsyncClient

from app.config import settings
from app.services import coach_service
from app.services.firestore_client import sessions_ref


@dataclass(frozen=True)
class PastSessionSummary:
    session_id: str
    summary: str
    last_message_at: datetime | None = None


def _truncate(text: str, max_chars: int) -> str:
    text = text.strip()
    if len(text) <= max_chars:
        return text
    return text[: max(0, max_chars - 4)].rstrip() + "\n..."


def sanitize_diary_context(diary_content: str | None) -> str | None:
    """Keep diary context bounded before persisting or prompting with it."""
    if not diary_content:
        return None
    return _truncate(diary_content, settings.coach_context_diary_max_chars)


def trim_history(history: list[dict] | None) -> list[dict[str, str]]:
    """Keep recent same-session messages within message and character budgets."""
    if not history:
        return []

    normalized: list[dict[str, str]] = []
    for item in history:
        role = item.get("role")
        content = str(item.get("content") or "").strip()
        if role not in {"user", "assistant"} or not content:
            continue
        normalized.append({"role": role, "content": content})

    recent = normalized[-settings.coach_context_history_max_messages :]
    total = 0
    kept_reversed: list[dict[str, str]] = []
    for item in reversed(recent):
        length = len(item["content"])
        if kept_reversed and total + length > settings.coach_context_history_max_chars:
            break
        kept_reversed.append(item)
        total += length
    return list(reversed(kept_reversed))


async def get_past_session_summaries(
    db: AsyncClient,
    *,
    user_id: str,
    current_session_id: str | None,
    limit: int | None = None,
) -> list[PastSessionSummary]:
    """Fetch recent saved summaries for the same user, excluding this session."""
    max_items = limit or settings.coach_context_summary_limit
    if max_items <= 0:
        return []

    summaries: list[PastSessionSummary] = []
    query = sessions_ref(db).where("user_id", "==", user_id)
    async for doc in query.stream():
        if doc.id == current_session_id:
            continue
        data = doc.to_dict() or {}
        raw_summary = data.get("summary") or data.get("title")
        if not raw_summary:
            continue
        summaries.append(
            PastSessionSummary(
                session_id=doc.id,
                summary=_truncate(
                    str(raw_summary),
                    settings.coach_context_summary_max_chars,
                ),
                last_message_at=data.get("last_message_at"),
            )
        )

    summaries.sort(
        key=lambda item: (
            item.last_message_at.timestamp() if item.last_message_at else 0.0
        ),
        reverse=True,
    )
    return summaries[:max_items]


def format_context_block(summaries: list[PastSessionSummary]) -> str | None:
    """Build the dynamic memory block injected into the next coach turn."""
    if not summaries:
        return None

    lines = [
        "【過去セッション要約】",
        "これは参考情報です。断定せず、必要な時だけユーザーの言葉として扱ってください。",
    ]
    for item in summaries:
        prefix = ""
        if item.last_message_at:
            prefix = item.last_message_at.date().isoformat() + " "
        lines.append(f"- {prefix}{item.summary}")
    return "\n".join(lines)


def join_context_blocks(blocks: list[str | None]) -> str | None:
    """Join optional dynamic prompt blocks into one bounded user-side context."""
    normalized = [block.strip() for block in blocks if block and block.strip()]
    if not normalized:
        return None
    return "\n\n".join(normalized)


async def build_context_block(
    db: AsyncClient,
    *,
    user_id: str,
    current_session_id: str | None,
) -> str | None:
    summaries = await get_past_session_summaries(
        db,
        user_id=user_id,
        current_session_id=current_session_id,
    )
    return format_context_block(summaries)


def _user_messages_text(messages: list[dict[str, str]]) -> str:
    user_lines: list[str] = []
    for item in messages[-settings.coach_summary_source_max_messages :]:
        if item.get("role") != "user":
            continue
        content = str(item.get("content") or "").strip()
        if content:
            user_lines.append(f"- {content}")
    return "\n".join(user_lines)


async def generate_session_summary(
    messages: list[dict[str, str]],
    *,
    diary_context: str | None = None,
    config: dict | None = None,
) -> str | None:
    """Summarize a session from user utterances only."""
    user_text = _user_messages_text(messages)
    if not user_text:
        return None

    diary_part = ""
    if diary_context:
        diary_part = (
            "【日記コンテキスト】\n"
            + _truncate(diary_context, settings.coach_context_summary_max_chars)
            + "\n\n"
        )

    prompt = (
        "あなたはCycleの会話要約器です。\n"
        "コーチ発話は解釈材料にせず、ユーザー発話だけから短い記憶メモを作ってください。\n"
        "評価、診断、助言、重要度の説明は禁止です。\n"
        "ユーザーが実際に使った言葉をできるだけ残し、1〜3文の日本語で返してください。\n\n"
        f"{diary_part}"
        "【ユーザー発話】\n"
        f"{user_text}"
    )
    summary = await coach_service.quick_text(
        prompt,
        max_tokens=240,
        config=config,
    )
    summary = summary.strip()
    if not summary:
        return None
    return _truncate(summary, settings.coach_summary_max_chars)


async def maybe_update_session_summary(
    session_doc: Any,
    *,
    session_data: dict,
    messages: list[dict[str, str]],
    diary_context: str | None,
    config: dict | None = None,
    now: datetime | None = None,
) -> None:
    """Generate and persist a bounded session summary when it is stale."""
    if not settings.coach_summary_generation_enabled:
        return

    user_message_count = sum(1 for item in messages if item.get("role") == "user")
    if user_message_count < settings.coach_summary_min_user_messages:
        return

    message_count = int(
        session_data.get("message_count", len(messages)) or len(messages)
    )
    summary_message_count = int(session_data.get("summary_message_count", 0) or 0)
    has_summary = bool(session_data.get("summary"))
    if has_summary:
        refresh_interval = max(settings.coach_summary_refresh_message_interval, 1)
        if message_count - summary_message_count < refresh_interval:
            return

    summary = await generate_session_summary(
        messages,
        diary_context=diary_context,
        config=config,
    )
    if not summary:
        return

    await session_doc.update(
        {
            "summary": summary,
            "summary_generated_at": now or datetime.now(UTC),
            "summary_message_count": message_count,
        }
    )
