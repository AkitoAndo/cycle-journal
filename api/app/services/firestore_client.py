"""Firestore async client."""

from google.cloud.firestore import AsyncClient

from app.config import settings

_db: AsyncClient | None = None


def get_db() -> AsyncClient:
    """Get or create Firestore async client."""
    global _db
    if _db is None:
        _db = AsyncClient(
            project=settings.gcp_project_id,
            database=settings.firestore_database_id,
        )
    return _db


def users_ref(db: AsyncClient):
    return db.collection("users")


def sessions_ref(db: AsyncClient):
    return db.collection("sessions")


def tasks_ref(db: AsyncClient):
    return db.collection("tasks")


def journals_ref(db: AsyncClient):
    return db.collection("journals")


def refresh_tokens_ref(db: AsyncClient):
    return db.collection("refresh_tokens")


def prompt_versions_ref(db: AsyncClient):
    return db.collection("prompt_versions")


def prompt_deployments_ref(db: AsyncClient):
    return db.collection("prompt_deployments")


def prompt_test_logs_ref(db: AsyncClient):
    return db.collection("prompt_test_logs")
