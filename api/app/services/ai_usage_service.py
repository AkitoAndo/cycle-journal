"""Monthly AI usage budget guardrail."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from math import ceil

from fastapi import HTTPException
from google.cloud.firestore import SERVER_TIMESTAMP, AsyncClient

from app.config import settings
from app.services import coach_service


@dataclass(frozen=True)
class UsageEstimate:
    period: str
    model: str
    input_tokens: int
    output_tokens_reserved: int
    cost_micro_usd: int

    @property
    def total_tokens(self) -> int:
        return self.input_tokens + self.output_tokens_reserved


def current_period(now: datetime | None = None) -> str:
    dt = now or datetime.now(UTC)
    return dt.strftime("%Y-%m")


def monthly_budget_micro_usd() -> int:
    budget_usd = settings.ai_monthly_budget_yen / settings.ai_usage_usd_to_jpy
    return int(budget_usd * 1_000_000)


def _active_model_prices() -> tuple[str, float, float]:
    if settings.use_gemini_fallback:
        return (
            settings.gemini_model_coach,
            settings.gemini_pro_input_usd_per_1m,
            settings.gemini_pro_output_usd_per_1m,
        )
    return (
        settings.claude_model_coach,
        settings.claude_sonnet_input_usd_per_1m,
        settings.claude_sonnet_output_usd_per_1m,
    )


def estimate_coach_request(
    *,
    message: str,
    history: list[dict] | None = None,
    diary_content: str | None = None,
    period: str | None = None,
) -> UsageEstimate:
    """Estimate cost before the model call.

    This intentionally over-reserves: system prompt, history, diary context, user input,
    and the maximum response budget are all counted before calling the provider.
    """
    input_chars = len(coach_service.SYSTEM_PROMPT) + len(message)
    if diary_content:
        input_chars += len(diary_content)
    if history:
        input_chars += sum(len(str(item.get("content") or "")) for item in history)

    chars_per_token = max(settings.ai_usage_chars_per_input_token, 0.1)
    input_tokens = max(1, ceil(input_chars / chars_per_token))
    output_tokens = min(settings.claude_max_tokens, settings.coach_output_max_tokens_cap)

    model, input_usd_per_1m, output_usd_per_1m = _active_model_prices()
    input_micro_usd = ceil(input_tokens * input_usd_per_1m)
    output_micro_usd = ceil(output_tokens * output_usd_per_1m)
    return UsageEstimate(
        period=period or current_period(),
        model=model,
        input_tokens=input_tokens,
        output_tokens_reserved=output_tokens,
        cost_micro_usd=input_micro_usd + output_micro_usd,
    )


async def reserve_monthly_budget(
    db: AsyncClient,
    *,
    user_id: str,
    estimate: UsageEstimate,
) -> None:
    """Reserve estimated monthly AI cost or raise 429."""
    doc_id = f"{user_id}_{estimate.period}"
    doc = db.collection("ai_usage_monthly").document(doc_id)
    snap = await doc.get()
    data = snap.to_dict() if snap.exists else {}

    used_micro_usd = int(data.get("estimated_cost_micro_usd", 0) or 0)
    budget_micro_usd = monthly_budget_micro_usd()
    next_used_micro_usd = used_micro_usd + estimate.cost_micro_usd

    if next_used_micro_usd > budget_micro_usd:
        raise HTTPException(
            status_code=429,
            detail={
                "code": "ai_monthly_budget_exceeded",
                "period": estimate.period,
                "budget_yen": settings.ai_monthly_budget_yen,
                "estimated_used_yen": round(
                    used_micro_usd / 1_000_000 * settings.ai_usage_usd_to_jpy,
                    2,
                ),
            },
        )

    await doc.set(
        {
            "user_id": user_id,
            "period": estimate.period,
            "model": estimate.model,
            "request_count": int(data.get("request_count", 0) or 0) + 1,
            "estimated_input_tokens": int(data.get("estimated_input_tokens", 0) or 0)
            + estimate.input_tokens,
            "reserved_output_tokens": int(data.get("reserved_output_tokens", 0) or 0)
            + estimate.output_tokens_reserved,
            "estimated_total_tokens": int(data.get("estimated_total_tokens", 0) or 0)
            + estimate.total_tokens,
            "estimated_cost_micro_usd": next_used_micro_usd,
            "budget_micro_usd": budget_micro_usd,
            "budget_yen": settings.ai_monthly_budget_yen,
            "usd_to_jpy": settings.ai_usage_usd_to_jpy,
            "updated_at": SERVER_TIMESTAMP,
        },
        merge=True,
    )
