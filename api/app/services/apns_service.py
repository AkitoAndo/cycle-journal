"""Apple Push Notification service sender for silent subscription updates."""

from __future__ import annotations

import time
from typing import Any

import httpx
import jwt

from app.config import settings


def _apns_host() -> str:
    env = settings.apple_apns_env.lower()
    return "api.push.apple.com" if env == "production" else "api.sandbox.push.apple.com"


def _build_provider_token() -> str | None:
    if (
        not settings.apple_apns_team_id
        or not settings.apple_apns_key_id
        or not settings.apple_apns_private_key
    ):
        return None
    return jwt.encode(
        {"iss": settings.apple_apns_team_id, "iat": int(time.time())},
        settings.apple_apns_private_key,
        algorithm="ES256",
        headers={"kid": settings.apple_apns_key_id},
    )


async def send_silent_push(
    *,
    device_token: str,
    event: str,
    reason: str,
    extra: dict[str, Any] | None = None,
) -> bool:
    """Send one APNs background notification.

    Returns false for missing configuration or network/APNs errors so webhook handling
    never fails because a best-effort push could not be delivered.
    """
    provider_token = _build_provider_token()
    if provider_token is None:
        return False

    payload: dict[str, Any] = {
        "aps": {"content-available": 1},
        "cycle_event": event,
        "reason": reason,
    }
    if extra:
        payload.update(extra)

    url = f"https://{_apns_host()}/3/device/{device_token}"
    headers = {
        "authorization": f"bearer {provider_token}",
        "apns-topic": settings.apple_bundle_id,
        "apns-push-type": "background",
        "apns-priority": "5",
    }

    try:
        async with httpx.AsyncClient(timeout=5.0, http2=True) as client:
            response = await client.post(url, json=payload, headers=headers)
            return 200 <= response.status_code < 300
    except httpx.HTTPError:
        return False
