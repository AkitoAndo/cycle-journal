"""FastAPI dependencies."""

from fastapi import Depends, Request
from google.cloud.firestore import AsyncClient

from app.logging_config import uid_var
from app.middleware.auth_middleware import get_current_user_id
from app.services.firestore_client import get_db


async def get_firestore() -> AsyncClient:
    """Firestore client dependency."""
    return get_db()


async def get_current_user(request: Request) -> str:
    """Authenticated user_id dependency. uid を log ContextVar に bind する."""
    uid = await get_current_user_id(request)
    uid_var.set(uid)
    return uid


# Type aliases for use in Depends()
CurrentUser = Depends(get_current_user)
Firestore = Depends(get_firestore)
