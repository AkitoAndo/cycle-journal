"""AI monthly usage budget tests."""

from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException

from app.config import settings
from app.services import ai_usage_service


def test_monthly_budget_micro_usd(monkeypatch):
    monkeypatch.setattr(settings, "ai_monthly_budget_yen", 1000)
    monkeypatch.setattr(settings, "ai_usage_usd_to_jpy", 160.0)

    assert ai_usage_service.monthly_budget_micro_usd() == 6_250_000


def test_estimate_uses_gemini_prices_when_fallback_enabled(monkeypatch):
    monkeypatch.setattr(settings, "use_gemini_fallback", True)
    monkeypatch.setattr(settings, "ai_usage_chars_per_input_token", 1.0)
    monkeypatch.setattr(settings, "claude_max_tokens", 2000)
    monkeypatch.setattr(settings, "coach_output_max_tokens_cap", 4000)

    estimate = ai_usage_service.estimate_coach_request(
        message="今日は疲れた",
        history=[{"role": "assistant", "content": "前回の返答"}],
        diary_content="日記本文",
        period="2026-07",
    )

    assert estimate.period == "2026-07"
    assert estimate.model == settings.gemini_model_coach
    assert estimate.input_tokens > len("今日は疲れた")
    assert estimate.output_tokens_reserved == 2000
    assert estimate.cost_micro_usd > 0


@pytest.mark.asyncio
async def test_reserve_monthly_budget_creates_usage_doc(monkeypatch):
    monkeypatch.setattr(settings, "ai_monthly_budget_yen", 1000)
    monkeypatch.setattr(settings, "ai_usage_usd_to_jpy", 160.0)

    snapshot = MagicMock()
    snapshot.exists = False
    snapshot.to_dict.return_value = {}

    doc = MagicMock()
    doc.get = AsyncMock(return_value=snapshot)
    doc.set = AsyncMock()

    collection = MagicMock()
    collection.document.return_value = doc

    db = MagicMock()
    db.collection.return_value = collection

    estimate = ai_usage_service.UsageEstimate(
        period="2026-07",
        model="gemini-2.5-pro",
        input_tokens=1000,
        output_tokens_reserved=2000,
        cost_micro_usd=21_250,
    )

    await ai_usage_service.reserve_monthly_budget(
        db,
        user_id="user-1",
        estimate=estimate,
    )

    db.collection.assert_called_once_with("ai_usage_monthly")
    collection.document.assert_called_once_with("user-1_2026-07")
    doc.set.assert_awaited_once()
    payload = doc.set.await_args.args[0]
    assert payload["request_count"] == 1
    assert payload["estimated_total_tokens"] == 3000
    assert payload["estimated_cost_micro_usd"] == 21_250


@pytest.mark.asyncio
async def test_reserve_monthly_budget_rejects_over_limit(monkeypatch):
    monkeypatch.setattr(settings, "ai_monthly_budget_yen", 1000)
    monkeypatch.setattr(settings, "ai_usage_usd_to_jpy", 160.0)

    snapshot = MagicMock()
    snapshot.exists = True
    snapshot.to_dict.return_value = {"estimated_cost_micro_usd": 6_240_000}

    doc = MagicMock()
    doc.get = AsyncMock(return_value=snapshot)
    doc.set = AsyncMock()

    collection = MagicMock()
    collection.document.return_value = doc

    db = MagicMock()
    db.collection.return_value = collection

    estimate = ai_usage_service.UsageEstimate(
        period="2026-07",
        model="gemini-2.5-pro",
        input_tokens=1000,
        output_tokens_reserved=2000,
        cost_micro_usd=21_250,
    )

    with pytest.raises(HTTPException) as exc_info:
        await ai_usage_service.reserve_monthly_budget(
            db,
            user_id="user-1",
            estimate=estimate,
        )

    assert exc_info.value.status_code == 429
    assert exc_info.value.detail["code"] == "ai_monthly_budget_exceeded"
    doc.set.assert_not_awaited()
