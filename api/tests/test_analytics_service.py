"""GA4 Measurement Protocol sender tests (C-3 backend).

サーバーサイドで `trial_converted_to_paid` / `subscription_renewed` 等の
サブスクイベントを GA4 に送信するサービスのテスト。httpx は完全にモック化。
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest


@pytest.mark.asyncio
async def test_send_event_posts_to_measurement_protocol():
    """C-3: send_event は GA4 Measurement Protocol に POST する."""
    from app.services import analytics_service
    from app.services.analytics_service import send_event

    mock_response = MagicMock()
    mock_response.status_code = 204
    mock_response.raise_for_status = MagicMock()
    mock_client = MagicMock()
    mock_client.post = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=None)

    with (
        patch.object(analytics_service.settings, "ga4_measurement_id", "G-TEST123"),
        patch.object(analytics_service.settings, "ga4_api_secret", "secret-xyz"),
        patch(
            "app.services.analytics_service.httpx.AsyncClient",
            return_value=mock_client,
        ),
    ):
        await send_event(
            client_id="user-abc",
            event_name="trial_converted_to_paid",
            params={"product_id": "yearly_14400", "revenue_jpy": 14400},
            event_id="notif-uuid-1",
        )

    mock_client.post.assert_awaited_once()
    call = mock_client.post.call_args
    url = call.args[0]
    assert "/mp/collect" in url
    assert "measurement_id=" in url
    assert "api_secret=" in url
    body = call.kwargs["json"]
    assert body["client_id"] == "user-abc"
    assert len(body["events"]) == 1
    event = body["events"][0]
    assert event["name"] == "trial_converted_to_paid"
    assert event["params"]["product_id"] == "yearly_14400"
    assert event["params"]["revenue_jpy"] == 14400
    # 冪等化キー (Apple ASSN の notificationUUID 等) は event params に含める
    assert event["params"]["event_id"] == "notif-uuid-1"


@pytest.mark.asyncio
async def test_send_event_skips_when_not_configured():
    """C-3: ga4_measurement_id / ga4_api_secret 未設定なら何もしない(no-op)."""
    from app.services import analytics_service

    mock_client = MagicMock()
    mock_client.post = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=None)

    with (
        patch.object(analytics_service.settings, "ga4_measurement_id", ""),
        patch.object(analytics_service.settings, "ga4_api_secret", ""),
        patch(
            "app.services.analytics_service.httpx.AsyncClient",
            return_value=mock_client,
        ),
    ):
        await analytics_service.send_event(
            client_id="user-x",
            event_name="trial_started",
            params={},
        )

    mock_client.post.assert_not_called()


@pytest.mark.asyncio
async def test_send_event_swallows_network_errors():
    """C-3: ネットワークエラーで Webhook 処理を止めないため例外を握り潰す."""
    import httpx

    from app.services import analytics_service
    from app.services.analytics_service import send_event

    mock_client = MagicMock()
    mock_client.post = AsyncMock(side_effect=httpx.NetworkError("boom"))
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=None)

    with (
        patch.object(analytics_service.settings, "ga4_measurement_id", "G-TEST"),
        patch.object(analytics_service.settings, "ga4_api_secret", "secret"),
        patch(
            "app.services.analytics_service.httpx.AsyncClient",
            return_value=mock_client,
        ),
    ):
        # 例外が再送出されず None で返ることを確認
        result = await send_event(
            client_id="user-x",
            event_name="trial_started",
            params={},
        )

    assert result is None
