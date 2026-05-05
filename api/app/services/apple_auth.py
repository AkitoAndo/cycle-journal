"""Apple Sign in with Apple - identity token verification and revoke flow.

- verify_apple_token: identity_token を JWKS で検証し claims を返す
- exchange_apple_code: authorization_code を Apple refresh_token に交換する
- revoke_apple_refresh_token: Apple 側で refresh token を revoke する
"""

import json
import logging
import time
from typing import Any

import httpx
import jwt
from jwt.algorithms import RSAAlgorithm

from app.config import settings

logger = logging.getLogger(__name__)

# Apple公開鍵のキャッシュ
_apple_public_keys_cache: dict[str, Any] = {}
_cache_timestamp: float = 0
CACHE_TTL = 3600  # 1時間

# Apple OAuth エンドポイント
APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token"
APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke"
APPLE_AUDIENCE = "https://appleid.apple.com"

# client_secret JWT の有効期限 (秒) - Apple は最大 6 ヶ月だが短命運用
CLIENT_SECRET_TTL = 60 * 15  # 15 分


async def get_apple_public_keys() -> dict[str, Any]:
    """Appleの公開鍵を取得（キャッシュあり）."""
    global _apple_public_keys_cache, _cache_timestamp

    current_time = time.time()
    if _apple_public_keys_cache and (current_time - _cache_timestamp) < CACHE_TTL:
        return _apple_public_keys_cache

    url = "https://appleid.apple.com/auth/keys"
    async with httpx.AsyncClient() as client:
        response = await client.get(url, timeout=10)
        keys_data = response.json()

    # kid -> 公開鍵のマッピングを作成
    _apple_public_keys_cache.clear()
    for key in keys_data.get("keys", []):
        kid = key.get("kid")
        if kid:
            _apple_public_keys_cache[kid] = key

    _cache_timestamp = current_time
    return _apple_public_keys_cache


async def verify_apple_token(identity_token: str) -> dict[str, Any]:
    """Apple ID Tokenを検証し、クレームを返す."""
    # JWTヘッダーをデコードしてkidを取得
    unverified_header = jwt.get_unverified_header(identity_token)
    kid = unverified_header.get("kid")

    if not kid:
        raise ValueError("Token missing kid in header")

    # 公開鍵を取得
    public_keys = await get_apple_public_keys()
    if kid not in public_keys:
        raise ValueError(f"Unknown key id: {kid}")

    # JWKから公開鍵を構築
    public_key = RSAAlgorithm.from_jwk(json.dumps(public_keys[kid]))

    # トークンを検証
    claims = jwt.decode(
        identity_token,
        public_key,
        algorithms=["RS256"],
        audience=settings.apple_bundle_id,
        issuer="https://appleid.apple.com",
    )

    return claims


# ----- client_secret 生成 / token 交換 / revoke -----

def _is_revoke_configured() -> bool:
    return bool(
        settings.apple_team_id
        and settings.apple_key_id
        and settings.apple_private_key
    )


def _generate_client_secret() -> str:
    """Apple OAuth 用の client_secret JWT を生成する (ES256)."""
    if not _is_revoke_configured():
        raise ValueError(
            "Apple sign-in revoke is not configured: "
            "APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY が設定されていません"
        )
    now = int(time.time())
    headers = {"kid": settings.apple_key_id}
    payload = {
        "iss": settings.apple_team_id,
        "iat": now,
        "exp": now + CLIENT_SECRET_TTL,
        "aud": APPLE_AUDIENCE,
        "sub": settings.apple_bundle_id,
    }
    return jwt.encode(
        payload,
        settings.apple_private_key,
        algorithm="ES256",
        headers=headers,
    )


async def exchange_apple_code(authorization_code: str) -> dict[str, Any]:
    """authorization_code を Apple の refresh_token / id_token に交換する."""
    client_secret = _generate_client_secret()
    data = {
        "client_id": settings.apple_bundle_id,
        "client_secret": client_secret,
        "code": authorization_code,
        "grant_type": "authorization_code",
    }
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.post(
            APPLE_TOKEN_URL,
            data=data,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
    if response.status_code != 200:
        raise ValueError(
            f"Apple token exchange failed: {response.status_code} {response.text}"
        )
    return response.json()


async def revoke_apple_refresh_token(refresh_token: str) -> bool:
    """Apple の refresh_token を revoke する.

    Returns: 成功時 True、未設定または失敗時 False。
    アカウント削除フローでは失敗してもユーザー削除は続行するため、例外は投げない。
    """
    if not _is_revoke_configured():
        logger.warning("Apple sign-in revoke is not configured; skipping")
        return False
    if not refresh_token:
        return False
    try:
        client_secret = _generate_client_secret()
    except ValueError:
        return False

    data = {
        "client_id": settings.apple_bundle_id,
        "client_secret": client_secret,
        "token": refresh_token,
        "token_type_hint": "refresh_token",
    }
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                APPLE_REVOKE_URL,
                data=data,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )
    except httpx.HTTPError as exc:
        logger.warning("Apple revoke request failed: %s", exc)
        return False

    if response.status_code != 200:
        logger.warning(
            "Apple revoke returned %d: %s",
            response.status_code,
            response.text,
        )
        return False
    return True
