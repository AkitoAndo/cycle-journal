"""APNs silent push sender tests."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest


@pytest.mark.asyncio
async def test_send_silent_push_skips_when_not_configured():
    from app.services import apns_service

    with (
        patch.object(apns_service.settings, "apple_apns_team_id", ""),
        patch.object(apns_service.settings, "apple_apns_key_id", ""),
        patch.object(apns_service.settings, "apple_apns_private_key", ""),
        patch("app.services.apns_service.httpx.AsyncClient") as mock_client,
    ):
        sent = await apns_service.send_silent_push(
            device_token="abcd",
            event="cancel_trial_notifications",
            reason="subscription_auto_renew_disabled",
        )

    assert sent is False
    mock_client.assert_not_called()


@pytest.mark.asyncio
async def test_send_silent_push_posts_background_payload():
    from app.services import apns_service

    mock_response = MagicMock(status_code=200)
    mock_client = AsyncMock()
    mock_client.post.return_value = mock_response
    mock_context = AsyncMock()
    mock_context.__aenter__.return_value = mock_client

    with (
        patch.object(apns_service.settings, "apple_apns_team_id", "TEAMID1234"),
        patch.object(apns_service.settings, "apple_apns_key_id", "KEYID12345"),
        patch.object(apns_service.settings, "apple_apns_private_key", "pem"),
        patch.object(apns_service.jwt, "encode", return_value="provider-token"),
        patch("app.services.apns_service.httpx.AsyncClient", return_value=mock_context),
    ):
        sent = await apns_service.send_silent_push(
            device_token="abcd",
            event="cancel_trial_notifications",
            reason="subscription_auto_renew_disabled",
        )

    assert sent is True
    _, kwargs = mock_client.post.call_args
    assert kwargs["json"]["aps"] == {"content-available": 1}
    assert kwargs["headers"]["apns-push-type"] == "background"
    assert kwargs["headers"]["apns-priority"] == "5"
