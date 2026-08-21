"""Security tests for the remote Coach Studio MCP server."""

from __future__ import annotations

import time
from unittest.mock import AsyncMock, patch

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey
from fastapi.testclient import TestClient
from mcp.server.fastmcp.exceptions import ToolError

from app.config import settings
from app.mcp_auth import OIDCJWTVerifier
from app.mcp_server import app, coach_deploy_to_dev, mcp

ISSUER = "https://cycle-test.us.auth0.com/"
AUDIENCE = "https://cycle-coach-mcp.example.com/mcp"
EMAIL_CLAIM = "https://cycle-journal.app/email"
VERIFIED_CLAIM = "https://cycle-journal.app/email_verified"
ALLOWED_EMAIL = "28ww.lo.ol.ww28@gmail.com"


def _verifier() -> tuple[OIDCJWTVerifier, RSAPrivateKey]:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    verifier = OIDCJWTVerifier(
        issuer=ISSUER,
        audience=AUDIENCE,
        allowed_emails={ALLOWED_EMAIL, "takeshiogata1105@gmail.com"},
        required_scope="coach:manage",
        email_claim=EMAIL_CLAIM,
        email_verified_claim=VERIFIED_CLAIM,
    )
    verifier._keys = {"test-key": private_key.public_key()}
    verifier._keys_expires_at = time.monotonic() + 3600
    return verifier, private_key


def _token(private_key: RSAPrivateKey, **overrides: object) -> str:
    now = int(time.time())
    claims = {
        "iss": ISSUER,
        "aud": AUDIENCE,
        "sub": "google-oauth2|owner",
        "azp": "codex-client",
        "iat": now,
        "exp": now + 300,
        "scope": "openid profile email coach:manage",
        EMAIL_CLAIM: ALLOWED_EMAIL,
        VERIFIED_CLAIM: True,
    }
    claims.update(overrides)
    return jwt.encode(
        claims,
        private_key,
        algorithm="RS256",
        headers={"kid": "test-key"},
    )


@pytest.mark.asyncio
async def test_mcp_accepts_only_allowlisted_verified_human() -> None:
    verifier, private_key = _verifier()

    access_token = await verifier.verify_token(_token(private_key))

    assert access_token is not None
    assert access_token.subject == "google-oauth2|owner"
    assert access_token.claims is not None
    assert access_token.claims[EMAIL_CLAIM] == ALLOWED_EMAIL


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "overrides",
    [
        {EMAIL_CLAIM: "someone@example.com"},
        {VERIFIED_CLAIM: False},
        {"scope": "openid profile email"},
        {"aud": "https://wrong.example.com/mcp"},
    ],
)
async def test_mcp_rejects_invalid_identity(overrides: dict[str, object]) -> None:
    verifier, private_key = _verifier()

    assert await verifier.verify_token(_token(private_key, **overrides)) is None


def test_mcp_http_surface_requires_bearer_token() -> None:
    with TestClient(app) as client:
        health = client.get("/health")
        response = client.post("/mcp", json={})
        metadata = client.get("/.well-known/oauth-protected-resource/mcp")

    assert health.status_code == 200
    assert response.status_code == 401
    assert "resource_metadata=" in response.headers["www-authenticate"]
    assert metadata.status_code == 200
    assert metadata.json()["authorization_servers"] == [settings.mcp_oauth_issuer]


@pytest.mark.asyncio
async def test_mcp_exposes_only_safe_dev_prompt_tools() -> None:
    tools = {tool.name: tool for tool in await mcp.list_tools()}

    assert set(tools) == {
        "coach_get_current_config",
        "coach_list_versions",
        "coach_get_version",
        "coach_validate_changes",
        "coach_test_config",
        "coach_save_draft",
        "coach_deploy_to_dev",
    }
    assert tools["coach_deploy_to_dev"].annotations is not None
    assert tools["coach_deploy_to_dev"].annotations.destructiveHint is True
    assert all("prod" not in name for name in tools)


@pytest.mark.asyncio
async def test_dev_deployment_requires_exact_confirmation() -> None:
    with patch("app.mcp_server._audit", new_callable=AsyncMock):
        with pytest.raises(ToolError, match="確認文字列"):
            await coach_deploy_to_dev("version-1", "yes")
