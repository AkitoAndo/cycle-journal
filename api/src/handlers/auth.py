"""Auth handler - Sign in with Apple token verification."""

import json
import os
import time
import urllib.request
from typing import Any

import jwt
from jwt.algorithms import RSAAlgorithm


# Apple公開鍵のキャッシュ（Lambda実行間で再利用）
_apple_public_keys_cache: dict[str, Any] = {}
_cache_timestamp: float = 0
CACHE_TTL = 3600  # 1時間


def get_apple_public_keys() -> dict[str, Any]:
    """Appleの公開鍵を取得（キャッシュあり）."""
    global _apple_public_keys_cache, _cache_timestamp

    current_time = time.time()
    if _apple_public_keys_cache and (current_time - _cache_timestamp) < CACHE_TTL:
        return _apple_public_keys_cache

    url = "https://appleid.apple.com/auth/keys"
    with urllib.request.urlopen(url, timeout=10) as response:
        keys_data = json.loads(response.read().decode())

    # kid -> 公開鍵のマッピングを作成
    _apple_public_keys_cache = {}
    for key in keys_data.get("keys", []):
        kid = key.get("kid")
        if kid:
            _apple_public_keys_cache[kid] = key

    _cache_timestamp = current_time
    return _apple_public_keys_cache


def verify_apple_token(identity_token: str) -> dict[str, Any]:
    """Apple ID Tokenを検証し、クレームを返す."""
    # JWTヘッダーをデコードしてkidを取得
    unverified_header = jwt.get_unverified_header(identity_token)
    kid = unverified_header.get("kid")

    if not kid:
        raise ValueError("Token missing kid in header")

    # 公開鍵を取得
    public_keys = get_apple_public_keys()
    if kid not in public_keys:
        raise ValueError(f"Unknown key id: {kid}")

    # JWKから公開鍵を構築
    public_key = RSAAlgorithm.from_jwk(json.dumps(public_keys[kid]))

    # Bundle IDを取得（環境変数から）
    bundle_id = os.environ.get("APPLE_BUNDLE_ID", "com.cycle.journal")

    # トークンを検証
    claims = jwt.decode(
        identity_token,
        public_key,
        algorithms=["RS256"],
        audience=bundle_id,
        issuer="https://appleid.apple.com",
    )

    return claims


def handler(event, context):
    """Auth verify endpoint.

    POST /auth/verify
    Body: {
        "identity_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
    }
    """
    try:
        # リクエストボディをパース
        body = json.loads(event.get("body", "{}"))
        identity_token = body.get("identity_token", "")

        if not identity_token:
            return {
                "statusCode": 400,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*",
                },
                "body": json.dumps({
                    "error": {
                        "code": "ValidationError",
                        "message": "identity_token is required",
                    }
                }),
            }

        # トークンを検証
        claims = verify_apple_token(identity_token)

        # ユーザー情報を返却
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": json.dumps({
                "data": {
                    "user_id": claims.get("sub"),
                    "apple_user_id": claims.get("sub"),
                    "email": claims.get("email"),
                    "is_new_user": False,  # TODO: DynamoDBで確認
                    "verified": True,
                }
            }),
        }

    except jwt.ExpiredSignatureError:
        return {
            "statusCode": 401,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": json.dumps({
                "error": {
                    "code": "TokenExpired",
                    "message": "Identity token has expired",
                }
            }),
        }
    except jwt.InvalidTokenError as e:
        return {
            "statusCode": 401,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": json.dumps({
                "error": {
                    "code": "InvalidToken",
                    "message": str(e),
                }
            }),
        }
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": json.dumps({
                "error": {
                    "code": "InvalidJSON",
                    "message": "Request body must be valid JSON",
                }
            }),
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": json.dumps({
                "error": {
                    "code": "InternalError",
                    "message": str(e),
                }
            }),
        }
