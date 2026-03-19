"""Health check endpoint."""

from datetime import UTC, datetime

from fastapi import APIRouter

from app.config import settings

router = APIRouter(tags=["System"])


@router.get("/health")
async def health():
    return {
        "status": "healthy",
        "stage": settings.environment,
        "timestamp": datetime.now(UTC).isoformat(),
    }
