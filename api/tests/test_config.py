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


def test_firestore_database_id_defaults_to_default_database():
    """Firestore DB は既存本番データ互換のため (default) を既定にする."""
    settings = Settings()
    assert settings.firestore_database_id == "(default)"


def test_firestore_database_id_overridable_via_env():
    """dev/prod Cloud Run から FIRESTORE_DATABASE_ID で DB を分離できる."""
    with patch.dict(os.environ, {"FIRESTORE_DATABASE_ID": "dev"}):
        settings = Settings()
        assert settings.firestore_database_id == "dev"


def test_google_oauth_client_ids_combines_legacy_and_additional_values():
    with patch.dict(
        os.environ,
        {
            "GOOGLE_CLIENT_ID": "ios-client",
            "GOOGLE_CLIENT_IDS": "web-dev, web-prod,web-dev",
        },
    ):
        settings = Settings()
        assert settings.google_oauth_client_ids == [
            "ios-client",
            "web-dev",
            "web-prod",
        ]


def test_cors_origins_are_explicit_and_deduplicated():
    with patch.dict(
        os.environ,
        {
            "CORS_ALLOWED_ORIGINS": (
                "https://app.example.com, http://localhost:3000,"
                "https://app.example.com"
            )
        },
    ):
        settings = Settings()
        assert settings.cors_origins == [
            "https://app.example.com",
            "http://localhost:3000",
        ]
