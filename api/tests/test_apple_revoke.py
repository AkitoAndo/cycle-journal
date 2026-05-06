"""Apple Sign in client_secret 生成 / revoke 関連のテスト."""

import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec


def _generate_test_es256_pem() -> str:
    """テスト用 ES256 鍵を PEM 形式で生成."""
    private_key = ec.generate_private_key(ec.SECP256R1())
    pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    return pem.decode("utf-8")


def test_generate_client_secret_includes_required_claims(monkeypatch):
    from app.config import settings
    from app.services.apple_auth import _generate_client_secret

    monkeypatch.setattr(settings, "apple_team_id", "TEAM12345A")
    monkeypatch.setattr(settings, "apple_key_id", "KEY1234ABC")
    monkeypatch.setattr(settings, "apple_private_key", _generate_test_es256_pem())
    monkeypatch.setattr(settings, "apple_bundle_id", "com.example.test")

    token = _generate_client_secret()

    header = jwt.get_unverified_header(token)
    assert header["alg"] == "ES256"
    assert header["kid"] == "KEY1234ABC"

    payload = jwt.decode(token, options={"verify_signature": False})
    assert payload["iss"] == "TEAM12345A"
    assert payload["sub"] == "com.example.test"
    assert payload["aud"] == "https://appleid.apple.com"
    assert payload["exp"] > payload["iat"]


def test_generate_client_secret_raises_when_unconfigured(monkeypatch):
    from app.config import settings
    from app.services.apple_auth import _generate_client_secret

    monkeypatch.setattr(settings, "apple_team_id", "")
    monkeypatch.setattr(settings, "apple_key_id", "")
    monkeypatch.setattr(settings, "apple_private_key", "")

    with pytest.raises(ValueError):
        _generate_client_secret()


@pytest.mark.asyncio
async def test_revoke_returns_false_when_unconfigured(monkeypatch):
    from app.config import settings
    from app.services.apple_auth import revoke_apple_refresh_token

    monkeypatch.setattr(settings, "apple_team_id", "")

    result = await revoke_apple_refresh_token("some-token")
    assert result is False


@pytest.mark.asyncio
async def test_revoke_returns_false_for_empty_token(monkeypatch):
    from app.config import settings
    from app.services.apple_auth import revoke_apple_refresh_token

    monkeypatch.setattr(settings, "apple_team_id", "TEAM12345A")
    monkeypatch.setattr(settings, "apple_key_id", "KEY1234ABC")
    monkeypatch.setattr(settings, "apple_private_key", _generate_test_es256_pem())

    result = await revoke_apple_refresh_token("")
    assert result is False
