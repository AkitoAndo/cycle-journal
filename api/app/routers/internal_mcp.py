"""Least-privilege API surface for the authenticated Coach Studio MCP service."""

from __future__ import annotations

import asyncio

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from google.auth.transport import requests as google_requests
from google.cloud.firestore import AsyncClient
from google.oauth2 import id_token

from app.config import settings
from app.dependencies import get_firestore
from app.logging_config import uid_var
from app.models.admin import (
    PromptCurrentData,
    PromptDeploymentData,
    PromptDeploymentRequest,
    PromptTestData,
    PromptTestRequest,
    PromptVersionCreateRequest,
    PromptVersionData,
)
from app.services import prompt_admin_service, prompt_service

router = APIRouter(prefix="/internal/mcp", tags=["Internal MCP"])


async def get_mcp_actor(
    request: Request,
    x_cycle_mcp_actor: str = Header(default=""),
) -> str:
    authorization = request.headers.get("authorization", "")
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="service authentication required")
    if not settings.mcp_service_account_email:
        raise HTTPException(
            status_code=503,
            detail="MCP service identity is not configured",
        )

    token = authorization.removeprefix("Bearer ").strip()
    try:
        claims = await asyncio.to_thread(
            id_token.verify_oauth2_token,
            token,
            google_requests.Request(),
            settings.mcp_backend_api_url,
        )
    except ValueError as exc:
        raise HTTPException(status_code=401, detail="invalid service identity") from exc

    caller_email = str(claims.get("email", "")).lower()
    if caller_email != settings.mcp_service_account_email.lower():
        raise HTTPException(status_code=403, detail="MCP service identity required")
    actor = x_cycle_mcp_actor.strip().lower()
    if actor not in settings.mcp_email_allowlist:
        raise HTTPException(status_code=403, detail="approved MCP actor required")
    uid_var.set(f"mcp:{actor}")
    return actor


@router.get("/prompts/current")
async def get_current_prompt(
    _: str = Depends(get_mcp_actor),
    db: AsyncClient = Depends(get_firestore),
):
    config, version_id = await prompt_service.get_active_config(db)
    return {
        "data": PromptCurrentData(
            prompt=str(config["system_prompt"]),
            config=config,
            version_id=version_id,
            source="version" if version_id else "internal",
        )
    }


@router.get("/prompts/versions")
async def list_prompt_versions(
    limit: int = 20,
    _: str = Depends(get_mcp_actor),
    db: AsyncClient = Depends(get_firestore),
):
    safe_limit = max(1, min(limit, 50))
    versions = await prompt_service.list_versions(db, limit=safe_limit)
    return {"data": {"versions": [PromptVersionData(**v) for v in versions]}}


@router.get("/prompts/versions/{version_id}")
async def get_prompt_version(
    version_id: str,
    _: str = Depends(get_mcp_actor),
    db: AsyncClient = Depends(get_firestore),
):
    version = await prompt_service.get_version(db, version_id)
    if version is None:
        raise HTTPException(status_code=404, detail="prompt version not found")
    return {"data": PromptVersionData(**version)}


@router.post("/prompts/versions")
async def create_prompt_version(
    body: PromptVersionCreateRequest,
    actor: str = Depends(get_mcp_actor),
    db: AsyncClient = Depends(get_firestore),
):
    version = await prompt_service.create_version(
        db,
        title=body.title,
        prompt=body.prompt,
        config=body.config.model_dump() if body.config else None,
        notes=body.notes,
        created_by=f"mcp:{actor}",
    )
    return {"data": PromptVersionData(**version)}


@router.post("/prompts/test")
async def test_prompt(
    body: PromptTestRequest,
    actor: str = Depends(get_mcp_actor),
    db: AsyncClient = Depends(get_firestore),
):
    try:
        result = await prompt_admin_service.run_prompt_test(db, body)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    log_id = await prompt_service.log_prompt_test(
        db,
        actor=f"mcp:{actor}",
        message=body.message,
        response=result.response,
        version_id=result.version_id,
        prompt=result.prompt,
        config=result.config,
        diary_content=body.diary_content,
        model=result.model,
    )
    return {
        "data": PromptTestData(
            message=result.response,
            version_id=result.version_id,
            log_id=log_id,
        )
    }


@router.post("/prompts/deployment")
async def deploy_prompt_version(
    body: PromptDeploymentRequest,
    actor: str = Depends(get_mcp_actor),
    db: AsyncClient = Depends(get_firestore),
):
    if settings.environment != "dev":
        raise HTTPException(
            status_code=403,
            detail="production deployment is not available to MCP",
        )
    try:
        deployment = await prompt_service.deploy_version(
            db,
            version_id=body.version_id,
            deployed_by=f"mcp:{actor}",
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return {"data": PromptDeploymentData(**deployment)}
