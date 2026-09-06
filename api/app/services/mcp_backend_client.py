"""Service-authenticated client for the MCP-specific internal API surface."""

from __future__ import annotations

import asyncio
from typing import Any

import httpx
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

from app.config import settings


class MCPBackendError(RuntimeError):
    pass


async def _service_token() -> str:
    return await asyncio.to_thread(
        id_token.fetch_id_token,
        google_requests.Request(),
        settings.mcp_backend_api_url,
    )


async def request(
    method: str,
    path: str,
    *,
    actor: str,
    params: dict[str, Any] | None = None,
    json_body: dict[str, Any] | None = None,
) -> Any:
    token = await _service_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "X-Cycle-MCP-Actor": actor,
    }
    async with httpx.AsyncClient(
        base_url=settings.mcp_backend_api_url,
        timeout=90.0,
    ) as client:
        response = await client.request(
            method,
            path,
            headers=headers,
            params=params,
            json=json_body,
        )
    if response.status_code >= 400:
        try:
            detail = response.json().get("detail")
        except ValueError:
            detail = response.text
        raise MCPBackendError(str(detail or f"backend returned {response.status_code}"))
    return response.json().get("data")
