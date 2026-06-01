"""GA4 Measurement Protocol 設定テスト (C-3 backend)."""

import os
from unittest.mock import patch

from app.config import Settings


def test_ga4_measurement_id_exists():
    """C-3: GA4 Measurement ID 設定項目."""
    settings = Settings()
    assert hasattr(settings, "ga4_measurement_id")


def test_ga4_api_secret_exists():
    """C-3: GA4 Measurement Protocol API Secret 設定項目."""
    settings = Settings()
    assert hasattr(settings, "ga4_api_secret")


def test_ga4_endpoint_defaults_to_production():
    """C-3: 既定エンドポイントは https://www.google-analytics.com/mp/collect."""
    settings = Settings()
    assert settings.ga4_endpoint.startswith("https://www.google-analytics.com")


def test_ga4_overridable_via_env():
    """C-3: env var で上書き可能(本番/デバッグエンドポイント切替用)."""
    with patch.dict(
        os.environ,
        {"GA4_MEASUREMENT_ID": "G-TEST123", "GA4_API_SECRET": "secret-xyz"},
    ):
        settings = Settings()
        assert settings.ga4_measurement_id == "G-TEST123"
        assert settings.ga4_api_secret == "secret-xyz"


def test_apns_config_exists():
    """B5: APNs silent push 設定項目."""
    from app.config import settings

    assert hasattr(settings, "apple_apns_team_id")
    assert hasattr(settings, "apple_apns_key_id")
    assert hasattr(settings, "apple_apns_private_key")
    assert hasattr(settings, "apple_apns_env")
    assert settings.apple_apns_env == "Sandbox"
