"""Tests for server-issued access and refresh tokens."""

import pytest

from app.exceptions import InvalidTokenError, RefreshTokenError, TokenExpiredError
from app.services import token_service


def test_access_token_roundtrip():
    token, expires_in = token_service.create_access_token("user-1", "apple")
    assert expires_in > 0

    claims = token_service.verify_access_token(token)
    assert claims["sub"] == "user-1"
    assert claims["provider"] == "apple"
    assert claims["type"] == "access"


def test_access_token_rejects_tampered():
    token, _ = token_service.create_access_token("user-1", "apple")
    tampered = token[:-4] + "xxxx"
    with pytest.raises(InvalidTokenError):
        token_service.verify_access_token(tampered)


def test_access_token_rejects_non_access_type():
    import jwt as pyjwt

    from app.config import settings

    payload = {
        "sub": "user-1",
        "type": "refresh",
        "iss": settings.jwt_issuer,
        "exp": 9999999999,
    }
    token = pyjwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    with pytest.raises(InvalidTokenError):
        token_service.verify_access_token(token)


def test_access_token_expiry(monkeypatch):
    import jwt as pyjwt

    from app.config import settings

    payload = {
        "sub": "user-1",
        "provider": "apple",
        "type": "access",
        "iss": settings.jwt_issuer,
        "exp": 1,
    }
    token = pyjwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    with pytest.raises(TokenExpiredError):
        token_service.verify_access_token(token)


@pytest.mark.asyncio
async def test_refresh_token_create_and_verify(mock_firestore):
    raw = await token_service.create_refresh_token(mock_firestore, "user-1", "apple")
    assert raw

    # mock_firestore's default snapshot.exists=False so verify would fail;
    # flip the stored document to look valid.
    import datetime as dt

    mock_firestore._mock_snapshot.exists = True
    mock_firestore._mock_snapshot.to_dict.return_value = {
        "user_id": "user-1",
        "provider": "apple",
        "expires_at": dt.datetime.now(dt.UTC) + dt.timedelta(days=30),
    }

    user_id, provider = await token_service.verify_refresh_token(mock_firestore, raw)
    assert user_id == "user-1"
    assert provider == "apple"


@pytest.mark.asyncio
async def test_refresh_token_rejects_unknown(mock_firestore):
    mock_firestore._mock_snapshot.exists = False
    with pytest.raises(RefreshTokenError):
        await token_service.verify_refresh_token(mock_firestore, "bogus")
