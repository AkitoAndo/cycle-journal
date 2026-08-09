"""Coach service tests.

通常は Claude path (use_gemini_fallback=False) の動作を検証する。
Gemini fallback の動作（use_gemini_fallback=True がデフォルト）は別テストで確認。
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
    for element in ["Soil", "Water", "Root", "Trunk", "Branch", "Leaf", "Fruit", "Sky"]:
        assert element in prompt, f"{element} が SYSTEM_PROMPT に含まれていない"
    assert "わたし" in prompt


def test_build_user_content_includes_dynamic_context():
    content = coach_service.build_user_content(
        "この日記について話したいです",
        diary_content="朝から緊張していた",
        context_block="【過去セッション要約】\n- 仕事の疲れ",
    )

    assert "【参考コンテキスト】" in content
    assert "仕事の疲れ" in content
    assert "【日記の内容】" in content
    assert "朝から緊張していた" in content
    assert "【ユーザーのメッセージ】" in content


@pytest.mark.asyncio
async def test_chat_uses_coach_model_in_claude_mode(monkeypatch):
    """Claude モード (use_gemini_fallback=False) では Sonnet を使う."""
    monkeypatch.setattr(settings, "use_gemini_fallback", False)

    with patch("app.services.coach_service._get_claude_client") as mock_get:
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
async def test_chat_passes_system_with_cache_control_in_claude_mode(monkeypatch):
    """Claude モードでは system を list 形式で渡し cache_control ephemeral を付ける."""
    monkeypatch.setattr(settings, "use_gemini_fallback", False)

    with patch("app.services.coach_service._get_claude_client") as mock_get:
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
        assert isinstance(system, list), "system は list で渡されるべき"
        assert len(system) >= 1
        first = system[0]
        assert first["type"] == "text"
        assert first["text"] == coach_service.SYSTEM_PROMPT
        assert first["cache_control"] == {"type": "ephemeral"}


@pytest.mark.asyncio
async def test_chat_accepts_system_prompt_override_in_claude_mode(monkeypatch):
    """Admin prompt tests can run through the real chat path with an override."""
    monkeypatch.setattr(settings, "use_gemini_fallback", False)

    with patch("app.services.coach_service._get_claude_client") as mock_get:
        client = MagicMock()
        block = MagicMock()
        block.text = "ok"
        response = MagicMock()
        response.content = [block]
        client.messages.create.return_value = response
        mock_get.return_value = client

        await coach_service.chat(user_message="hi", system_prompt="custom prompt")

        system = client.messages.create.call_args.kwargs["system"]
        assert system[0]["text"] == "custom prompt"


@pytest.mark.asyncio
async def test_chat_uses_gemini_when_fallback_enabled(monkeypatch):
    """Gemini fallback モードでは Gemini モデルを呼ぶ."""
    monkeypatch.setattr(settings, "use_gemini_fallback", True)

    with patch("app.services.coach_service._get_gemini_client") as mock_get:
        client = MagicMock()
        response = MagicMock()
        response.text = "そう感じたんだね。"
        client.models.generate_content.return_value = response
        mock_get.return_value = client

        result = await coach_service.chat(user_message="今日は疲れた")

        assert result == "そう感じたんだね。"
        call_kwargs = client.models.generate_content.call_args.kwargs
        assert call_kwargs["model"] == settings.gemini_model_coach
        # system_instruction は config 経由で渡される
        cfg = call_kwargs["config"]
        assert cfg.system_instruction == coach_service.SYSTEM_PROMPT


@pytest.mark.asyncio
async def test_quick_text_uses_gemini_quick_when_fallback_enabled(monkeypatch):
    """要約などの短い抽出は Gemini fallback 時も quick モデルを使う."""
    monkeypatch.setattr(settings, "use_gemini_fallback", True)

    with patch("app.services.coach_service._get_gemini_client") as mock_get:
        client = MagicMock()
        response = MagicMock()
        response.text = "要約"
        client.models.generate_content.return_value = response
        mock_get.return_value = client

        result = await coach_service.quick_text("要約して")

        assert result == "要約"
        call_kwargs = client.models.generate_content.call_args.kwargs
        assert call_kwargs["model"] == settings.gemini_model_quick
