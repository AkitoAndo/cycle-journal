"""Configuration tests (B-1: model ID split for coach vs quick-classify)."""

import os
from unittest.mock import patch

from app.config import Settings


def test_claude_model_coach_default_is_sonnet():
    """B-1: 用途別モデル ID 分離 - coach 用は Sonnet 系."""
    settings = Settings()
    assert hasattr(settings, "claude_model_coach")
    assert "sonnet" in settings.claude_model_coach.lower()


def test_claude_model_quick_default_is_haiku():
    """B-1: 用途別モデル ID 分離 - quick(分類・要約) 用は Haiku 系."""
    settings = Settings()
    assert hasattr(settings, "claude_model_quick")
    assert "haiku" in settings.claude_model_quick.lower()


def test_claude_model_coach_overridable_via_env():
    """B-1: env var で coach モデル ID を上書き可能."""
    with patch.dict(os.environ, {"CLAUDE_MODEL_COACH": "claude-sonnet-test@99999999"}):
        settings = Settings()
        assert settings.claude_model_coach == "claude-sonnet-test@99999999"


def test_claude_model_quick_overridable_via_env():
    """B-1: env var で quick モデル ID を上書き可能."""
    with patch.dict(os.environ, {"CLAUDE_MODEL_QUICK": "claude-haiku-test@99999999"}):
        settings = Settings()
        assert settings.claude_model_quick == "claude-haiku-test@99999999"
