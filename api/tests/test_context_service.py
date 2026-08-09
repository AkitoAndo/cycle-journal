"""Coach context memory service tests."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.config import settings
from app.services import context_service


def test_trim_history_keeps_recent_valid_messages(monkeypatch):
    monkeypatch.setattr(settings, "coach_context_history_max_messages", 2)
    monkeypatch.setattr(settings, "coach_context_history_max_chars", 1_000)

    history = [
        {"role": "system", "content": "ignore"},
        {"role": "user", "content": "first"},
        {"role": "assistant", "content": "second"},
        {"role": "user", "content": "third"},
        {"role": "assistant", "content": ""},
    ]

    assert context_service.trim_history(history) == [
        {"role": "assistant", "content": "second"},
        {"role": "user", "content": "third"},
    ]


def test_format_context_block_includes_past_summaries():
    block = context_service.format_context_block(
        [
            context_service.PastSessionSummary(
                session_id="old-1",
                summary="仕事の疲れについて話した",
                last_message_at=datetime(2026, 7, 25, tzinfo=UTC),
            )
        ]
    )

    assert block is not None
    assert "過去セッション要約" in block
    assert "2026-07-25 仕事の疲れについて話した" in block


@pytest.mark.asyncio
async def test_get_past_session_summaries_filters_current_and_empty():
    def make_doc(doc_id: str, data: dict) -> MagicMock:
        doc = MagicMock()
        doc.id = doc_id
        doc.to_dict.return_value = data
        return doc

    async def stream():
        yield make_doc("current", {"summary": "current"})
        yield make_doc("old-1", {"summary": "前回の要約"})
        yield make_doc("old-2", {"title": None})
        yield make_doc("old-3", {"title": "タイトルだけ"})

    query = MagicMock()
    query.order_by.return_value = query
    query.limit.return_value = query
    query.stream.return_value = stream()

    collection = MagicMock()
    collection.where.return_value = query

    db = MagicMock()
    db.collection.return_value = collection

    summaries = await context_service.get_past_session_summaries(
        db,
        user_id="user-1",
        current_session_id="current",
        limit=2,
    )

    assert [item.session_id for item in summaries] == ["old-1", "old-3"]
    assert summaries[1].summary == "タイトルだけ"
    collection.where.assert_called_once_with("user_id", "==", "user-1")


@pytest.mark.asyncio
async def test_generate_session_summary_uses_user_messages_only(monkeypatch):
    captured: dict[str, str] = {}

    async def fake_quick_text(prompt, *, max_tokens, config=None, system_prompt=None):
        captured["prompt"] = prompt
        captured["max_tokens"] = str(max_tokens)
        return "仕事の疲れについて話した"

    monkeypatch.setattr(context_service.coach_service, "quick_text", fake_quick_text)

    result = await context_service.generate_session_summary(
        [
            {"role": "assistant", "content": "コーチの解釈は含めない"},
            {"role": "user", "content": "今日は仕事で疲れた"},
        ],
        diary_context="朝から緊張していた",
        config={"use_gemini_fallback": True},
    )

    assert result == "仕事の疲れについて話した"
    assert "今日は仕事で疲れた" in captured["prompt"]
    assert "朝から緊張していた" in captured["prompt"]
    assert "コーチの解釈は含めない" not in captured["prompt"]


@pytest.mark.asyncio
async def test_maybe_update_session_summary_persists_when_stale(monkeypatch):
    generate = AsyncMock(return_value="仕事の疲れについて話した")
    monkeypatch.setattr(context_service, "generate_session_summary", generate)

    session_doc = MagicMock()
    session_doc.update = AsyncMock()
    now = datetime(2026, 8, 9, tzinfo=UTC)

    await context_service.maybe_update_session_summary(
        session_doc,
        session_data={"message_count": 2},
        messages=[
            {"role": "user", "content": "今日は疲れた"},
            {"role": "assistant", "content": "そう感じたんだね。"},
        ],
        diary_context=None,
        config={"use_gemini_fallback": True},
        now=now,
    )

    session_doc.update.assert_awaited_once()
    payload = session_doc.update.await_args.args[0]
    assert payload["summary"] == "仕事の疲れについて話した"
    assert payload["summary_generated_at"] == now
    assert payload["summary_message_count"] == 2


@pytest.mark.asyncio
async def test_maybe_update_session_summary_skips_fresh_summary(monkeypatch):
    generate = AsyncMock(return_value="new")
    monkeypatch.setattr(context_service, "generate_session_summary", generate)
    monkeypatch.setattr(settings, "coach_summary_refresh_message_interval", 4)

    session_doc = MagicMock()
    session_doc.update = AsyncMock()

    await context_service.maybe_update_session_summary(
        session_doc,
        session_data={
            "summary": "existing",
            "summary_message_count": 2,
            "message_count": 4,
        },
        messages=[
            {"role": "user", "content": "one"},
            {"role": "assistant", "content": "two"},
            {"role": "user", "content": "three"},
            {"role": "assistant", "content": "four"},
        ],
        diary_context=None,
    )

    generate.assert_not_awaited()
    session_doc.update.assert_not_awaited()
