"""OAuth access-token verification for the Coach Studio MCP resource server."""

from __future__ import annotations

import asyncio
import time
from typing import Any
from urllib.parse import urljoin

import httpx
import jwt
from mcp.server.auth.provider import AccessToken, TokenVerifier


class OIDCJWTVerifier(TokenVerifier):
    """Verify OIDC JWTs and enforce the human-user email allowlist."""

    def __init__(
        self,
        *,
        issuer: str,
        audience: str,
        allowed_emails: set[str],
        required_scope: str,
        email_claim: str,
        email_verified_claim: str,
        jwks_uri: str = "",
        cache_seconds: int = 3600,
    ) -> None:
        self.issuer = issuer.rstrip("/") + "/"
        self.audience = audience
        self.allowed_emails = {email.lower() for email in allowed_emails}
        self.required_scope = required_scope
        self.email_claim = email_claim
        self.email_verified_claim = email_verified_claim
        self.jwks_uri = jwks_uri
        self.cache_seconds = cache_seconds
        self._keys: dict[str, Any] = {}
        self._keys_expires_at = 0.0
        self._lock = asyncio.Lock()

    async def _resolve_jwks_uri(self, client: httpx.AsyncClient) -> str:
        if self.jwks_uri:
            return self.jwks_uri
        metadata_url = urljoin(
            self.issuer,
            ".well-known/openid-configuration",
        )
        response = await client.get(metadata_url)
        response.raise_for_status()
        metadata = response.json()
        if str(metadata.get("issuer", "")).rstrip("/") != self.issuer.rstrip("/"):
            raise ValueError("OIDC discovery issuer mismatch")
        jwks_uri = str(metadata.get("jwks_uri", ""))
        if not jwks_uri.startswith("https://"):
            raise ValueError("OIDC jwks_uri must use HTTPS")
        self.jwks_uri = jwks_uri
        return jwks_uri

    async def _refresh_keys(self) -> None:
        async with self._lock:
            if self._keys and time.monotonic() < self._keys_expires_at:
                return
            async with httpx.AsyncClient(timeout=10.0) as client:
                jwks_uri = await self._resolve_jwks_uri(client)
                response = await client.get(jwks_uri)
                response.raise_for_status()
                jwks = response.json()
            keys: dict[str, Any] = {}
            for key_data in jwks.get("keys", []):
                kid = key_data.get("kid")
                if kid:
                    keys[str(kid)] = jwt.PyJWK.from_dict(key_data).key
            if not keys:
                raise ValueError("OIDC JWKS contains no usable keys")
            self._keys = keys
            self._keys_expires_at = time.monotonic() + self.cache_seconds

    async def verify_token(self, token: str) -> AccessToken | None:
        try:
            header = jwt.get_unverified_header(token)
            kid = str(header.get("kid", ""))
            if not kid:
                return None
            if kid not in self._keys or time.monotonic() >= self._keys_expires_at:
                await self._refresh_keys()
            key = self._keys.get(kid)
            if key is None:
                # One forced refresh supports normal signing-key rotation.
                self._keys_expires_at = 0.0
                await self._refresh_keys()
                key = self._keys.get(kid)
            if key is None:
                return None

            claims = jwt.decode(
                token,
                key,
                algorithms=["RS256"],
                audience=self.audience,
                issuer=self.issuer,
                options={"require": ["exp", "iat", "iss", "sub", "aud"]},
            )
            email = str(
                claims.get(self.email_claim) or claims.get("email") or ""
            ).strip().lower()
            email_verified = claims.get(self.email_verified_claim)
            if email_verified is None:
                email_verified = claims.get("email_verified")
            if email_verified is not True or email not in self.allowed_emails:
                return None

            raw_scope = claims.get("scope", "")
            scopes = (
                [str(value) for value in raw_scope]
                if isinstance(raw_scope, list)
                else str(raw_scope).split()
            )
            if self.required_scope not in scopes:
                return None
            return AccessToken(
                token=token,
                client_id=str(claims.get("azp") or claims.get("client_id") or "mcp"),
                scopes=scopes,
                expires_at=int(claims["exp"]),
                resource=self.audience,
                subject=str(claims["sub"]),
                claims=claims,
            )
        except (httpx.HTTPError, jwt.PyJWTError, TypeError, ValueError):
            return None
