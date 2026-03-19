"""Auth endpoints - Apple ID token verification."""

from datetime import UTC, datetime

import jwt as pyjwt
from fastapi import APIRouter, Depends
from google.cloud.firestore import AsyncClient

from app.dependencies import get_firestore
from app.exceptions import InvalidTokenError, TokenExpiredError, ValidationError
from app.models.auth import VerifyTokenData, VerifyTokenRequest
from app.services.apple_auth import verify_apple_token
from app.services.firestore_client import users_ref

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/verify")
async def verify_token(
    body: VerifyTokenRequest,
    db: AsyncClient = Depends(get_firestore),
):
    """Apple Identity Tokenを検証し、ユーザーを作成または取得."""
    if not body.identity_token:
        raise ValidationError("identity_token is required")

    try:
        claims = await verify_apple_token(body.identity_token)
    except pyjwt.ExpiredSignatureError:
        raise TokenExpiredError()
    except pyjwt.InvalidTokenError as e:
        raise InvalidTokenError(str(e))
    except ValueError as e:
        raise InvalidTokenError(str(e))

    apple_user_id = claims.get("sub", "")
    email = claims.get("email")

    # Firestoreでユーザーを検索 or 作成
    ref = users_ref(db)
    user_doc = ref.document(apple_user_id)
    snapshot = await user_doc.get()

    now = datetime.now(UTC)
    is_new_user = not snapshot.exists

    if is_new_user:
        user_data = {
            "apple_user_id": apple_user_id,
            "email": email,
            "display_name": None,
            "settings": {"notification_enabled": False, "reminder_time": None},
            "created_at": now,
            "updated_at": now,
        }
        await user_doc.set(user_data)
        created_at = now
    else:
        created_at = snapshot.get("created_at") or now

    return {
        "data": VerifyTokenData(
            user_id=apple_user_id,
            apple_user_id=apple_user_id,
            email=email,
            is_new_user=is_new_user,
            created_at=created_at,
        )
    }
