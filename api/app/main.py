"""CycleJournal API - FastAPI application."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.exceptions import AppError, app_error_handler
from app.logging_config import setup_logging
from app.middleware.request_id import RequestIdMiddleware
from app.routers import (
    admin,
    auth,
    coach,
    health,
    iap,
    internal_mcp,
    journals,
    sessions,
    tasks,
    users,
)

setup_logging(project_id=settings.gcp_project_id)

app = FastAPI(
    title="CycleJournal API",
    version="0.1.0",
    docs_url="/docs" if settings.environment == "dev" else None,
)

app.add_middleware(RequestIdMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_exception_handler(AppError, app_error_handler)

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(internal_mcp.router)
app.include_router(coach.router)
app.include_router(sessions.router)
app.include_router(tasks.router)
app.include_router(journals.router)
app.include_router(users.router)
app.include_router(iap.router)
