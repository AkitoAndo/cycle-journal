"""Auth endpoints - Apple / Google token verification."""

from datetime import UTC, datetime

import jwt as pyjwt
from fastapi import APIRouter, Depends
from google.cloud.firestore import AsyncClient

from app.dependencies import get_firestore
from app.exceptions import InvalidTokenError, TokenExpiredError, ValidationError
from app.models.auth import GoogleVerifyRequest, VerifyTokenData, VerifyTokenRequest
from app.services.apple_auth import verify_apple_token
from app.services.firestore_client import users_ref
from app.services.google_auth import verify_google_token

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

    user_id, is_new_user, created_at = await _find_or_create_user(
        db=db,
        user_id=apple_user_id,
        email=email,
        provider_field="apple_user_id",
        provider_value=apple_user_id,
    )

    return {
        "data": VerifyTokenData(
            user_id=user_id,
            apple_user_id=apple_user_id,
            email=email,
            is_new_user=is_new_user,
            created_at=created_at,
        )
    }


@router.post("/google")
async def verify_google(
    body: GoogleVerifyRequest,
    db: AsyncClient = Depends(get_firestore),
):
    """Google ID Tokenを検証し、ユーザーを作成または取得."""
    if not body.id_token:
        raise ValidationError("id_token is required")

    try:
        claims = await verify_google_token(body.id_token)
    except ValueError as e:
        raise InvalidTokenError(str(e))

    google_user_id = claims.get("sub", "")
    email = claims.get("email")

    user_id, is_new_user, created_at = await _find_or_create_user(
        db=db,
        user_id=f"google_{google_user_id}",
        email=email,
        provider_field="google_user_id",
        provider_value=google_user_id,
    )

    return {
        "data": VerifyTokenData(
            user_id=f"google_{google_user_id}",
            google_user_id=google_user_id,
            email=email,
            is_new_user=is_new_user,
            created_at=created_at,
        )
    }


async def _find_or_create_user(
    db: AsyncClient,
    user_id: str,
    email: str | None,
    provider_field: str,
    provider_value: str,
) -> tuple[str, bool, datetime]:
    """Firestoreでユーザーを検索 or 作成."""
    ref = users_ref(db)
    user_doc = ref.document(user_id)
    snapshot = await user_doc.get()

    now = datetime.now(UTC)
    is_new_user = not snapshot.exists

    if is_new_user:
        user_data = {
            provider_field: provider_value,
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

    return user_id, is_new_user, created_at
