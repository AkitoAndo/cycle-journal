"""Auth endpoints - Apple / Google token verification and server token rotation."""

from datetime import UTC, datetime

import jwt as pyjwt
from fastapi import APIRouter, Depends
from google.cloud.firestore import AsyncClient

from app.dependencies import get_firestore
from app.exceptions import InvalidTokenError, TokenExpiredError, ValidationError
from app.models.auth import (
    GoogleVerifyRequest,
    RefreshTokenData,
    RefreshTokenRequest,
    VerifyTokenData,
    VerifyTokenRequest,
)
from app.services.apple_auth import (
    exchange_apple_code,
    verify_apple_token,
)
from app.services.firestore_client import users_ref
from app.services.google_auth import verify_google_token
from app.services.token_service import (
    create_access_token,
    create_refresh_token,
    revoke_refresh_token,
    rotate_refresh_token,
)

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/verify")
async def verify_token(
    body: VerifyTokenRequest,
    db: AsyncClient = Depends(get_firestore),
):
    """Apple Identity Tokenを検証し、ユーザーを作成または取得しトークンペアを発行."""
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

    # authorization_code があれば Apple refresh_token に交換して保存する。
    # アカウント削除時の revoke に必要（App Store ガイドライン 5.1.1(v)）。
    # 失敗しても識別トークン検証自体は成功しているのでサインインは続行する。
    apple_refresh_token: str | None = None
    if body.authorization_code:
        try:
            token_response = await exchange_apple_code(body.authorization_code)
            apple_refresh_token = token_response.get("refresh_token")
        except Exception:
            apple_refresh_token = None

    user_id, is_new_user, created_at = await _find_or_create_user(
        db=db,
        user_id=apple_user_id,
        email=email,
        provider_field="apple_user_id",
        provider_value=apple_user_id,
        apple_refresh_token=apple_refresh_token,
    )

    access_token, expires_in = create_access_token(user_id, "apple")
    refresh_token = await create_refresh_token(db, user_id, "apple")

    return {
        "data": VerifyTokenData(
            user_id=user_id,
            apple_user_id=apple_user_id,
            email=email,
            is_new_user=is_new_user,
            created_at=created_at,
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=expires_in,
        )
    }


@router.post("/google")
async def verify_google(
    body: GoogleVerifyRequest,
    db: AsyncClient = Depends(get_firestore),
):
    """Google ID Tokenを検証し、ユーザーを作成または取得しトークンペアを発行."""
    if not body.id_token:
        raise ValidationError("id_token is required")

    try:
        claims = await verify_google_token(body.id_token)
    except ValueError as e:
        raise InvalidTokenError(str(e))

    google_user_id = claims.get("sub", "")
    email = claims.get("email")
    user_id = f"google_{google_user_id}"

    _, is_new_user, created_at = await _find_or_create_user(
        db=db,
        user_id=user_id,
        email=email,
        provider_field="google_user_id",
        provider_value=google_user_id,
    )

    access_token, expires_in = create_access_token(user_id, "google")
    refresh_token = await create_refresh_token(db, user_id, "google")

    return {
        "data": VerifyTokenData(
            user_id=user_id,
            google_user_id=google_user_id,
            email=email,
            is_new_user=is_new_user,
            created_at=created_at,
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=expires_in,
        )
    }


@router.post("/refresh")
async def refresh(
    body: RefreshTokenRequest,
    db: AsyncClient = Depends(get_firestore),
):
    """Refresh tokenで新しいアクセストークンペアを発行（rotation）."""
    if not body.refresh_token:
        raise ValidationError("refresh_token is required")

    access_token, new_refresh, expires_in = await rotate_refresh_token(
        db,
        body.refresh_token,
    )

    return {
        "data": RefreshTokenData(
            access_token=access_token,
            refresh_token=new_refresh,
            expires_in=expires_in,
        )
    }


@router.post("/logout")
async def logout(
    body: RefreshTokenRequest,
    db: AsyncClient = Depends(get_firestore),
):
    """Refresh tokenを無効化."""
    if body.refresh_token:
        await revoke_refresh_token(db, body.refresh_token)
    return {"data": {"ok": True}}


async def _find_or_create_user(
    db: AsyncClient,
    user_id: str,
    email: str | None,
    provider_field: str,
    provider_value: str,
    apple_refresh_token: str | None = None,
) -> tuple[str, bool, datetime]:
    """Firestoreでユーザーを検索 or 作成."""
    ref = users_ref(db)
    user_doc = ref.document(user_id)
    snapshot = await user_doc.get()

    now = datetime.now(UTC)
    is_new_user = not snapshot.exists

    if is_new_user:
        user_data: dict = {
            provider_field: provider_value,
            "email": email,
            "display_name": None,
            "settings": {"notification_enabled": False, "reminder_time": None},
            "created_at": now,
            "updated_at": now,
        }
        if apple_refresh_token:
            user_data["apple_refresh_token"] = apple_refresh_token
        await user_doc.set(user_data)
        created_at = now
    else:
        created_at = snapshot.get("created_at") or now
        # 既存ユーザーで新しい apple_refresh_token を取得した場合は更新する。
        if apple_refresh_token:
            await user_doc.update(
                {
                    "apple_refresh_token": apple_refresh_token,
                    "updated_at": now,
                }
            )

    return user_id, is_new_user, created_at
