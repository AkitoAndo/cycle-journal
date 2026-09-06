"""Admin endpoints for prompt editing and live API tests."""

from fastapi import APIRouter, Depends, HTTPException, Request
from google.cloud.firestore import AsyncClient

from app.config import settings
from app.dependencies import get_firestore
from app.logging_config import uid_var
from app.middleware.auth_middleware import get_current_user_id
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
from app.services.firestore_client import users_ref

router = APIRouter(prefix="/admin", tags=["Admin"])


def _admin_email_set() -> set[str]:
    return {
        email.strip().lower()
        for email in settings.admin_google_emails.split(",")
        if email.strip()
    }


async def get_admin_user(
    request: Request,
    db: AsyncClient = Depends(get_firestore),
) -> str:
    if settings.environment == "dev" and settings.admin_auth_bypass:
        uid_var.set("local-admin")
        return "local-admin"

    user_id = await get_current_user_id(request)
    uid_var.set(user_id)
    snap = await users_ref(db).document(user_id).get()
    email = (snap.get("email") if snap.exists else None) or ""
    if email.lower() not in _admin_email_set():
        raise HTTPException(status_code=403, detail="admin access required")
    return user_id


@router.get("/access")
async def get_admin_access(_: str = Depends(get_admin_user)):
    return {"data": {"is_admin": True}}


@router.get("/prompts/versions")
async def list_prompt_versions(
    _: str = Depends(get_admin_user),
    db: AsyncClient = Depends(get_firestore),
):
    versions = await prompt_service.list_versions(db)
    return {"data": {"versions": [PromptVersionData(**v) for v in versions]}}


@router.post("/prompts/versions")
async def create_prompt_version(
    body: PromptVersionCreateRequest,
    user_id: str = Depends(get_admin_user),
    db: AsyncClient = Depends(get_firestore),
):
    version = await prompt_service.create_version(
        db,
        title=body.title,
        prompt=body.prompt,
        config=body.config.model_dump() if body.config else None,
        notes=body.notes,
        created_by=user_id,
    )
    return {"data": PromptVersionData(**version)}


@router.get("/prompts/deployment")
async def get_prompt_deployment(
    _: str = Depends(get_admin_user),
    db: AsyncClient = Depends(get_firestore),
):
    deployment = await prompt_service.get_deployment(db)
    return {"data": PromptDeploymentData(**deployment)}


@router.post("/prompts/deployment")
async def deploy_prompt_version(
    body: PromptDeploymentRequest,
    user_id: str = Depends(get_admin_user),
    db: AsyncClient = Depends(get_firestore),
):
    if settings.environment != "dev":
        raise HTTPException(
            status_code=403,
            detail=(
                "production prompt deployment requires the controlled release "
                "workflow"
            ),
        )
    try:
        deployment = await prompt_service.deploy_version(
            db,
            version_id=body.version_id,
            deployed_by=user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return {"data": PromptDeploymentData(**deployment)}


@router.get("/prompts/current")
async def get_current_prompt(
    _: str = Depends(get_admin_user),
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


@router.post("/prompts/test")
async def test_prompt(
    body: PromptTestRequest,
    user_id: str = Depends(get_admin_user),
    db: AsyncClient = Depends(get_firestore),
):
    if not body.prompt and not body.version_id:
        raise HTTPException(status_code=400, detail="prompt or version_id is required")

    try:
        result = await prompt_admin_service.run_prompt_test(db, body)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    log_id = await prompt_service.log_prompt_test(
        db,
        actor=user_id,
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
