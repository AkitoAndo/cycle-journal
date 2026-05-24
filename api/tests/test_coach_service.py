"""Coach service tests (B-3: prompt caching + SYSTEM_PROMPT expansion).

SYSTEM_PROMPT を Sonnet caching 最小要件(1024 tokens相当)に達するよう拡充し、
messages.create の system パラメータに cache_control を付与することを確認する。
"""

from unittest.mock import MagicMock, patch

import pytest

from app.config import settings
from app.services import coach_service

# 日本語 1024 tokens ≒ 約 1500-2000 chars (cl100k_base 系トークナイザ目安)
# 安全側に倒して 2000 chars を caching 適格境界とする
_SYSTEM_PROMPT_MIN_CHARS = 2000


def test_system_prompt_is_long_enough_for_caching():
    """B-3: SYSTEM_PROMPT は Sonnet prompt caching 最小要件を満たす長さ."""
    assert len(coach_service.SYSTEM_PROMPT) >= _SYSTEM_PROMPT_MIN_CHARS, (
        f"SYSTEM_PROMPT が {len(coach_service.SYSTEM_PROMPT)} chars。"
        f"caching 適格に {_SYSTEM_PROMPT_MIN_CHARS}+ chars が必要"
    )


def test_system_prompt_keeps_core_metaphor():
    """B-3: 拡張後も大樹メタファーの核となるキーワードを維持する."""
    prompt = coach_service.SYSTEM_PROMPT
    # Cycle 8 要素
    for element in ["Soil", "Water", "Root", "Trunk", "Branch", "Leaf", "Fruit", "Sky"]:
        assert element in prompt, f"{element} が SYSTEM_PROMPT に含まれていない"
    # 一人称
    assert "わたし" in prompt


@pytest.mark.asyncio
async def test_chat_uses_coach_model():
    """B-2 + B-3: chat() は claude_model_coach (Sonnet) を使う."""
    with patch("app.services.coach_service._get_client") as mock_get:
        client = MagicMock()
        block = MagicMock()
        block.text = "そう感じたんだね。"
        response = MagicMock()
        response.content = [block]
        client.messages.create.return_value = response
        mock_get.return_value = client

        await coach_service.chat(user_message="今日は疲れた")

        call_kwargs = client.messages.create.call_args.kwargs
        assert call_kwargs["model"] == settings.claude_model_coach


@pytest.mark.asyncio
async def test_chat_passes_system_with_cache_control():
    """B-3: chat() は system を list 形式で渡し cache_control ephemeral を付ける."""
    with patch("app.services.coach_service._get_client") as mock_get:
        client = MagicMock()
        block = MagicMock()
        block.text = "ok"
        response = MagicMock()
        response.content = [block]
        client.messages.create.return_value = response
        mock_get.return_value = client

        await coach_service.chat(user_message="hi")

        call_kwargs = client.messages.create.call_args.kwargs
        system = call_kwargs["system"]
        # list 形式 (str ではなく構造化された system block)
        assert isinstance(system, list), "system は list で渡されるべき"
        assert len(system) >= 1
        first = system[0]
        assert first["type"] == "text"
        assert first["text"] == coach_service.SYSTEM_PROMPT
        assert first["cache_control"] == {"type": "ephemeral"}
