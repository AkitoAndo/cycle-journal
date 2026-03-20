"""Google Sign-In - ID Token verification.

Uses google-auth library to verify Google ID tokens against Google's public keys.
"""

from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

from app.config import settings


async def verify_google_token(token: str) -> dict:
    """Google ID Tokenを検証し、クレームを返す.

    Args:
        token: Google Sign-Inから取得したID Token

    Returns:
        検証済みクレーム（sub, email, name等）

    Raises:
        ValueError: トークンが無効な場合
    """
    try:
        claims = id_token.verify_oauth2_token(
            token,
            google_requests.Request(),
            audience=settings.google_client_id,
        )
    except ValueError as e:
        raise ValueError(f"Invalid Google ID token: {e}")

    # issuer検証
    issuer = claims.get("iss", "")
    if issuer not in ("accounts.google.com", "https://accounts.google.com"):
        raise ValueError(f"Invalid issuer: {issuer}")

    return claims
