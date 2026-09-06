"""Service-to-service authorization tests for the MCP backend router."""

from unittest.mock import patch

import pytest
from fastapi import HTTPException
from starlette.requests import Request

from app.config import settings
from app.routers.internal_mcp import get_mcp_actor


def _request(token: str | None = "service-token") -> Request:
    headers = []
    if token is not None:
        headers.append((b"authorization", f"Bearer {token}".encode()))
    return Request({"type": "http", "headers": headers})


@pytest.mark.asyncio
async def test_internal_mcp_requires_service_token(monkeypatch) -> None:
    monkeypatch.setattr(
        settings,
        "mcp_service_account_email",
        "cycle-coach-mcp-dev@cycle-journal.iam.gserviceaccount.com",
    )

    with pytest.raises(HTTPException) as exc_info:
        await get_mcp_actor(_request(None), x_cycle_mcp_actor="")

    assert exc_info.value.status_code == 401


@pytest.mark.asyncio
async def test_internal_mcp_requires_exact_service_and_human(monkeypatch) -> None:
    service_email = "cycle-coach-mcp-dev@cycle-journal.iam.gserviceaccount.com"
    monkeypatch.setattr(settings, "mcp_service_account_email", service_email)
    with patch(
        "app.routers.internal_mcp.id_token.verify_oauth2_token",
        return_value={"email": service_email},
    ):
        actor = await get_mcp_actor(
            _request(),
            x_cycle_mcp_actor="28ww.lo.ol.ww28@gmail.com",
        )
        with pytest.raises(HTTPException) as exc_info:
            await get_mcp_actor(
                _request(),
                x_cycle_mcp_actor="someone@example.com",
            )

    assert actor == "28ww.lo.ol.ww28@gmail.com"
    assert exc_info.value.status_code == 403


@pytest.mark.asyncio
async def test_internal_mcp_rejects_other_service_identity(monkeypatch) -> None:
    monkeypatch.setattr(
        settings,
        "mcp_service_account_email",
        "cycle-coach-mcp-dev@cycle-journal.iam.gserviceaccount.com",
    )
    with patch(
        "app.routers.internal_mcp.id_token.verify_oauth2_token",
        return_value={"email": "other-service@cycle-journal.iam.gserviceaccount.com"},
    ):
        with pytest.raises(HTTPException) as exc_info:
            await get_mcp_actor(
                _request(),
                x_cycle_mcp_actor="28ww.lo.ol.ww28@gmail.com",
            )

    assert exc_info.value.status_code == 403
