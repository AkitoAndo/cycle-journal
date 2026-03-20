"""Bearer token extraction and JWT verification middleware.

Supports both Apple Identity Tokens and Google ID Tokens.
Determines provider by attempting Apple verification first, then Google.
"""

import jwt as pyjwt
from fastapi import Request

from app.exceptions import AuthenticationError, InvalidTokenError, TokenExpiredError
from app.services.apple_auth import verify_apple_token
from app.services.google_auth import verify_google_token


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

    # Apple JWTを先に試行
    try:
        claims = await verify_apple_token(token)
        user_id = claims.get("sub")
        if not user_id:
            raise InvalidTokenError("Token missing sub claim")
        return user_id
    except (pyjwt.ExpiredSignatureError, pyjwt.InvalidTokenError, ValueError):
        pass

    # Google ID Tokenを試行
    try:
        claims = await verify_google_token(token)
        google_user_id = claims.get("sub")
        if not google_user_id:
            raise InvalidTokenError("Token missing sub claim")
        return f"google_{google_user_id}"
    except ValueError:
        pass

    raise InvalidTokenError("Token could not be verified by any provider")
