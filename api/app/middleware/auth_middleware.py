"""Bearer token extraction and JWT verification middleware."""

import jwt as pyjwt
from fastapi import Request

from app.exceptions import AuthenticationError, InvalidTokenError, TokenExpiredError
from app.services.apple_auth import verify_apple_token


async def get_current_user_id(request: Request) -> str:
    """Extract and verify Bearer token, return user_id (Apple sub claim)."""
    auth_header = request.headers.get("Authorization", "")

    if not auth_header:
        raise AuthenticationError("Authorization header is required")

    if not auth_header.startswith("Bearer "):
        raise AuthenticationError("Invalid authorization scheme. Use: Bearer <token>")

    token = auth_header[7:]
    if not token:
        raise AuthenticationError("Token is required")

    try:
        claims = await verify_apple_token(token)
        user_id = claims.get("sub")
        if not user_id:
            raise InvalidTokenError("Token missing sub claim")
        return user_id
    except pyjwt.ExpiredSignatureError:
        raise TokenExpiredError()
    except pyjwt.InvalidTokenError as e:
        raise InvalidTokenError(str(e))
