"""IAP-related configuration tests (A backend)."""

import os
from unittest.mock import patch

from app.config import Settings


def test_apple_iap_issuer_id_exists():
    """A: App Store Connect IAP Issuer ID 設定項目."""
    settings = Settings()
    assert hasattr(settings, "apple_iap_issuer_id")


def test_apple_iap_key_id_exists():
    """A: App Store Connect IAP Key ID 設定項目."""
    settings = Settings()
    assert hasattr(settings, "apple_iap_key_id")


def test_apple_iap_private_key_exists():
    """A: IAP 用 .p8 秘密鍵(PEM)設定項目."""
    settings = Settings()
    assert hasattr(settings, "apple_iap_private_key")


def test_apple_iap_env_defaults_to_sandbox():
    """A: 既定は Sandbox(本番デプロイ時のみ Production を env で指定)."""
    settings = Settings()
    assert settings.apple_iap_env == "Sandbox"


def test_apple_iap_env_overridable_to_production():
    """A: env var で Production に切替可能."""
    with patch.dict(os.environ, {"APPLE_IAP_ENV": "Production"}):
        settings = Settings()
        assert settings.apple_iap_env == "Production"


def test_apple_iap_app_apple_id_optional_for_sandbox():
    """A: Sandbox では app_apple_id 不要(Production では必須・運用判断)."""
    settings = Settings()
    # Sandbox では None or 空 が許容される
    assert (
        settings.apple_iap_app_apple_id is None
        or settings.apple_iap_app_apple_id == 0
    )
