"""Firestore async client."""

from google.cloud.firestore import AsyncClient

from app.config import settings

_db: AsyncClient | None = None


def get_db() -> AsyncClient:
    """Get or create Firestore async client."""
    global _db
    if _db is None:
        _db = AsyncClient(project=settings.gcp_project_id)
    return _db


def users_ref(db: AsyncClient):
    return db.collection("users")


def sessions_ref(db: AsyncClient):
    return db.collection("sessions")


def tasks_ref(db: AsyncClient):
    return db.collection("tasks")
