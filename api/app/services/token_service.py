"""Server-issued JWT access tokens and opaque refresh tokens.

Access tokens: short-lived (1h), signed JWT containing user_id + provider.
Refresh tokens: long-lived (30d), opaque random strings. Server stores SHA-256
hash in Firestore; the raw token is shown to the client only once.
"""

import hashlib
import secrets
from datetime import UTC, datetime, timedelta
from typing import Literal

import jwt as pyjwt
from google.cloud.firestore import AsyncClient

from app.config import settings
from app.exceptions import InvalidTokenError, RefreshTokenError, TokenExpiredError
from app.services.firestore_client import refresh_tokens_ref

Provider = Literal["apple", "google"]
TOKEN_TYPE_ACCESS = "access"


def create_access_token(user_id: str, provider: Provider) -> tuple[str, int]:
    """Return (jwt, expires_in_seconds)."""
    now = datetime.now(UTC)
    expires_delta = timedelta(minutes=settings.access_token_expire_minutes)
    exp = now + expires_delta

    payload = {
        "sub": user_id,
        "provider": provider,
        "type": TOKEN_TYPE_ACCESS,
        "iss": settings.jwt_issuer,
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
    }
    token = pyjwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    return token, int(expires_delta.total_seconds())


def verify_access_token(token: str) -> dict:
    """Decode and validate a server-issued access token. Raises on failure."""
    try:
        claims = pyjwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
            issuer=settings.jwt_issuer,
        )
    except pyjwt.ExpiredSignatureError:
        raise TokenExpiredError()
    except pyjwt.InvalidTokenError as e:
        raise InvalidTokenError(str(e))

    if claims.get("type") != TOKEN_TYPE_ACCESS:
        raise InvalidTokenError("Token is not an access token")
    if not claims.get("sub"):
        raise InvalidTokenError("Token missing sub claim")
    return claims


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


async def create_refresh_token(
    db: AsyncClient, user_id: str, provider: Provider
) -> str:
    """Generate a new refresh token and persist its hash. Returns the raw token."""
    raw = secrets.token_urlsafe(32)
    token_hash = _hash_token(raw)
    now = datetime.now(UTC)
    expires_at = now + timedelta(days=settings.refresh_token_expire_days)

    await refresh_tokens_ref(db).document(token_hash).set(
        {
            "user_id": user_id,
            "provider": provider,
            "created_at": now,
            "expires_at": expires_at,
        }
    )
    return raw


async def verify_refresh_token(db: AsyncClient, token: str) -> tuple[str, Provider]:
    """Return (user_id, provider) if the refresh token is valid. Raise otherwise."""
    token_hash = _hash_token(token)
    doc = await refresh_tokens_ref(db).document(token_hash).get()

    if not doc.exists:
        raise RefreshTokenError()

    data = doc.to_dict() or {}
    expires_at = data.get("expires_at")
    if expires_at is None or expires_at < datetime.now(UTC):
        # Best-effort cleanup
        await refresh_tokens_ref(db).document(token_hash).delete()
        raise RefreshTokenError("Refresh token expired")

    user_id = data.get("user_id")
    provider = data.get("provider")
    if not user_id or provider not in ("apple", "google"):
        raise RefreshTokenError("Refresh token malformed")

    return user_id, provider  # type: ignore[return-value]


async def revoke_refresh_token(db: AsyncClient, token: str) -> None:
    """Delete the stored hash for this refresh token. No-op if absent."""
    token_hash = _hash_token(token)
    await refresh_tokens_ref(db).document(token_hash).delete()


async def rotate_refresh_token(
    db: AsyncClient, old_token: str
) -> tuple[str, str, int]:
    """Verify old refresh, revoke it, issue a new pair. Returns (access, refresh, access_expires_in)."""
    user_id, provider = await verify_refresh_token(db, old_token)
    await revoke_refresh_token(db, old_token)
    access_token, expires_in = create_access_token(user_id, provider)
    new_refresh = await create_refresh_token(db, user_id, provider)
    return access_token, new_refresh, expires_in
