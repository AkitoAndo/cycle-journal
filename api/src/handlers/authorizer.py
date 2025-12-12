"""Lambda Authorizer for API Gateway - Apple ID Token validation."""

import json
import os
import time
import urllib.request
from typing import Any

import jwt
from jwt.algorithms import RSAAlgorithm


# Apple公開鍵のキャッシュ
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

    _apple_public_keys_cache = {}
    for key in keys_data.get("keys", []):
        kid = key.get("kid")
        if kid:
            _apple_public_keys_cache[kid] = key

    _cache_timestamp = current_time
    return _apple_public_keys_cache


def verify_apple_token(identity_token: str) -> dict[str, Any]:
    """Apple ID Tokenを検証し、クレームを返す."""
    unverified_header = jwt.get_unverified_header(identity_token)
    kid = unverified_header.get("kid")

    if not kid:
        raise ValueError("Token missing kid in header")

    public_keys = get_apple_public_keys()
    if kid not in public_keys:
        raise ValueError(f"Unknown key id: {kid}")

    public_key = RSAAlgorithm.from_jwk(json.dumps(public_keys[kid]))
    bundle_id = os.environ.get("APPLE_BUNDLE_ID", "com.cycle.journal")

    claims = jwt.decode(
        identity_token,
        public_key,
        algorithms=["RS256"],
        audience=bundle_id,
        issuer="https://appleid.apple.com",
    )

    return claims


def generate_policy(principal_id: str, effect: str, resource: str, context: dict = None) -> dict:
    """IAMポリシーを生成."""
    policy = {
        "principalId": principal_id,
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": "execute-api:Invoke",
                    "Effect": effect,
                    "Resource": resource,
                }
            ],
        },
    }

    if context:
        policy["context"] = context

    return policy


def handler(event, context):
    """Lambda Authorizer handler.

    Validates Apple ID Token from Authorization header.
    Returns IAM policy allowing or denying API access.
    """
    try:
        # Authorizationヘッダーからトークンを取得
        auth_header = event.get("authorizationToken", "")

        if not auth_header:
            print("No authorization header")
            raise Exception("Unauthorized")

        # Bearer トークンを抽出
        if auth_header.startswith("Bearer "):
            token = auth_header[7:]
        else:
            token = auth_header

        if not token:
            print("No token in authorization header")
            raise Exception("Unauthorized")

        # トークンを検証
        claims = verify_apple_token(token)

        # ユーザーID（Apple sub claim）
        user_id = claims.get("sub", "unknown")

        # メソッドARNを取得してワイルドカード化
        method_arn = event.get("methodArn", "")
        # arn:aws:execute-api:region:account:api-id/stage/method/resource
        # -> arn:aws:execute-api:region:account:api-id/stage/*
        arn_parts = method_arn.split("/")
        if len(arn_parts) >= 2:
            resource_arn = f"{arn_parts[0]}/{arn_parts[1]}/*"
        else:
            resource_arn = method_arn

        # Allow ポリシーを返却
        return generate_policy(
            principal_id=user_id,
            effect="Allow",
            resource=resource_arn,
            context={
                "userId": user_id,
                "email": claims.get("email", ""),
            },
        )

    except jwt.ExpiredSignatureError:
        print("Token expired")
        raise Exception("Unauthorized")
    except jwt.InvalidTokenError as e:
        print(f"Invalid token: {e}")
        raise Exception("Unauthorized")
    except Exception as e:
        print(f"Authorization error: {e}")
        raise Exception("Unauthorized")
