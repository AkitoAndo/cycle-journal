"""GA4 Measurement Protocol — server-side event ingestion.

Apple App Store Server Notifications V2 受信時など、クライアント iOS では
発火できないサブスクリプション系イベント (trial_converted_to_paid /
subscription_renewed / subscription_cancelled / subscription_refunded /
trial_expired_without_conversion) を GA4 にサーバーから送信する。

設計方針:
- ga4_measurement_id / ga4_api_secret が未設定なら no-op (開発・テスト環境)
- ネットワーク例外は握り潰す (Apple Webhook の ACK を遅らせない・落とさない)
- params に event_id を入れることで GA4 側で重複排除可能にする
  (Apple ASSN の notificationUUID を渡せば再送に強い)

References:
- https://developers.google.com/analytics/devguides/collection/protocol/ga4
"""

from __future__ import annotations

from typing import Any

import httpx

from app.config import settings


async def send_event(
    *,
    client_id: str,
    event_name: str,
    params: dict[str, Any],
    event_id: str | None = None,
    user_id: str | None = None,
) -> dict[str, Any] | None:
    """GA4 にサーバーサイドイベントを 1 件送信する.

    Args:
        client_id: GA4 の client_id (iOS の Firebase Installations ID と紐付ける)
        event_name: 例 "trial_converted_to_paid"
        params: イベントパラメータ (product_id, revenue_jpy, paywall_variant 等)
        event_id: 冪等性キー (Apple ASSN notificationUUID 等)。GA4 で重複排除に利用
        user_id: 認証済みユーザー ID (App user_id property として送信)

    Returns:
        送信成功時はレスポンス JSON (debug endpoint の場合)、no-op / 失敗時は None
    """
    if not settings.ga4_measurement_id or not settings.ga4_api_secret:
        return None

    body_params = dict(params)
    if event_id is not None:
        body_params["event_id"] = event_id

    payload: dict[str, Any] = {
        "client_id": client_id,
        "events": [{"name": event_name, "params": body_params}],
    }
    if user_id is not None:
        payload["user_id"] = user_id

    url = (
        f"{settings.ga4_endpoint}"
        f"?measurement_id={settings.ga4_measurement_id}"
        f"&api_secret={settings.ga4_api_secret}"
    )

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.post(url, json=payload)
            resp.raise_for_status()
    except (httpx.HTTPError, httpx.NetworkError):
        # Webhook 処理を止めない: GA4 への送信失敗は ASSN 応答に影響させない
        return None

    return None
