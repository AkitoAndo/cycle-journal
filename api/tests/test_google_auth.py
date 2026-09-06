"""Google ID token audience verification tests."""

from unittest.mock import Mock

import pytest

from app.config import settings
from app.services.google_auth import verify_google_token


@pytest.mark.asyncio
async def test_verify_google_token_accepts_all_configured_client_ids(monkeypatch):
    verifier = Mock(
        return_value={
            "iss": "https://accounts.google.com",
            "aud": "web-development",
            "sub": "google-user",
        }
    )
    monkeypatch.setattr(settings, "google_client_id", "ios-client")
    monkeypatch.setattr(
        settings,
        "google_client_ids",
        "web-development,web-production",
    )
    monkeypatch.setattr(
        "app.services.google_auth.id_token.verify_oauth2_token",
        verifier,
    )

    claims = await verify_google_token("id-token")

    assert claims["sub"] == "google-user"
    assert verifier.call_args.kwargs["audience"] == [
        "ios-client",
        "web-development",
        "web-production",
    ]


@pytest.mark.asyncio
async def test_verify_google_token_rejects_missing_audience_configuration(monkeypatch):
    monkeypatch.setattr(settings, "google_client_id", "")
    monkeypatch.setattr(settings, "google_client_ids", "")

    with pytest.raises(ValueError, match="not configured"):
        await verify_google_token("id-token")
