"""User endpoints."""

from fastapi import APIRouter, Depends
from google.cloud.firestore import AsyncClient

from app.dependencies import get_current_user, get_firestore
from app.exceptions import NotFoundError
from app.models.user import UserData, UserSettings
from app.services.firestore_client import users_ref

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me")
async def get_me(
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """認証済みユーザー自身の情報を取得."""
    ref = users_ref(db)
    doc = ref.document(user_id)
    snapshot = await doc.get()

    if not snapshot.exists:
        raise NotFoundError("User")

    data = snapshot.to_dict() or {}
    user_settings = data.get("settings", {})

    return {
        "data": UserData(
            user_id=user_id,
            apple_user_id=data.get("apple_user_id", user_id),
            email=data.get("email"),
            display_name=data.get("display_name"),
            settings=UserSettings(**user_settings) if user_settings else UserSettings(),
            created_at=data.get("created_at"),
            updated_at=data.get("updated_at"),
        )
    }
