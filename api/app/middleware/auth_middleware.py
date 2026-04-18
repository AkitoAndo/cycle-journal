"""Bearer token extraction and server-issued JWT verification middleware.

Expects access tokens issued by /auth/verify, /auth/google, or /auth/refresh.
Apple/Google identity tokens are only accepted by /auth/verify and /auth/google
themselves, not by protected endpoints.
"""

from fastapi import Request

from app.exceptions import AuthenticationError
from app.services.token_service import verify_access_token


async def get_current_user_id(request: Request) -> str:
    """Extract and verify Bearer token, return user_id."""
    auth_header = request.headers.get("Authorization", "")

    if not auth_header:
        raise AuthenticationError("Authorization header is required")

    if not auth_header.startswith("Bearer "):
        raise AuthenticationError("Invalid authorization scheme. Use: Bearer <token>")

    token = auth_header[7:]
    if not token:
        raise AuthenticationError("Token is required")

    claims = verify_access_token(token)
    return claims["sub"]
