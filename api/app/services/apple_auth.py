"""Apple Sign in with Apple - JWKS fetch, cache, and JWT verification.

Ported from api/src/handlers/auth.py (Lambda version).
"""

import json
import time
from typing import Any

import httpx
import jwt
from jwt.algorithms import RSAAlgorithm

from app.config import settings

# Apple公開鍵のキャッシュ
_apple_public_keys_cache: dict[str, Any] = {}
_cache_timestamp: float = 0
CACHE_TTL = 3600  # 1時間


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
