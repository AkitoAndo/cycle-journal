"""Prompt version storage, lookup, deployment, and test logging."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Any

from google.cloud.firestore import AsyncClient

from app.config import settings
from app.services import coach_graph, coach_prompt_core, coach_service
from app.services.firestore_client import (
    prompt_deployments_ref,
    prompt_test_logs_ref,
    prompt_versions_ref,
)

CURRENT_DEPLOYMENT_ID = "current"


def default_config() -> dict[str, Any]:
    return {
        "system_prompt": coach_service.SYSTEM_PROMPT,
        "use_langgraph": settings.use_langgraph,
        "use_gemini_fallback": settings.use_gemini_fallback,
        "claude_model_coach": settings.claude_model_coach,
        "claude_model_quick": settings.claude_model_quick,
        "gemini_model_coach": settings.gemini_model_coach,
        "gemini_model_quick": settings.gemini_model_quick,
        "temperature": settings.claude_temperature,
        "max_tokens": settings.claude_max_tokens,
        "output_max_tokens_cap": settings.coach_output_max_tokens_cap,
        "analyze_emotion_prompt": coach_graph.ANALYZE_EMOTION_PROMPT,
        "determine_cycle_prompt": coach_graph.DETERMINE_CYCLE_PROMPT,
        "analysis_injection_prompt": coach_graph.ANALYSIS_INJECTION_PROMPT,
        "safety_filter_prompt": coach_graph.SAFETY_FILTER_PROMPT,
        "coach_phase_modules": dict(coach_prompt_core.PHASE_MODULES),
        "coach_action_core_checklist": coach_prompt_core.ACTION_CORE_CHECKLIST,
        "coach_layer8_crisis_prompt": coach_prompt_core.LAYER8_CRISIS_PROMPT,
        "coach_professional_boundary_prompt": (
            coach_prompt_core.PROFESSIONAL_BOUNDARY_PROMPT
        ),
        "coach_vocabulary_lint_enabled": True,
    }


def normalize_config(data: dict[str, Any] | None) -> dict[str, Any]:
    config = default_config()
    if data:
        raw = data.get("config") if "config" in data else data
        if isinstance(raw, dict):
            config.update({k: v for k, v in raw.items() if v is not None})
        if data.get("prompt"):
            config["system_prompt"] = data["prompt"]
    return config


def _iso(value: Any) -> str | None:
    if value is None:
        return None
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


def _version_payload(version_id: str, data: dict[str, Any]) -> dict[str, Any]:
    config = normalize_config(data)
    return {
        "version_id": version_id,
        "title": data.get("title") or "",
        "prompt": config["system_prompt"],
        "config": config,
        "notes": data.get("notes"),
        "status": data.get("status") or "draft",
        "created_by": data.get("created_by") or "",
        "created_at": _iso(data.get("created_at")),
    }


async def create_version(
    db: AsyncClient,
    *,
    title: str,
    prompt: str,
    config: dict[str, Any] | None = None,
    notes: str | None,
    created_by: str,
) -> dict[str, Any]:
    version_id = str(uuid.uuid4())
    now = datetime.now(UTC)
    normalized_config = normalize_config({"config": config or {}, "prompt": prompt})
    data = {
        "title": title,
        "prompt": normalized_config["system_prompt"],
        "config": normalized_config,
        "notes": notes,
        "status": "draft",
        "created_by": created_by,
        "created_at": now,
    }
    await prompt_versions_ref(db).document(version_id).set(data)
    return _version_payload(version_id, data)


async def list_versions(db: AsyncClient, limit: int = 50) -> list[dict[str, Any]]:
    query = (
        prompt_versions_ref(db)
        .order_by("created_at", direction="DESCENDING")
        .limit(limit)
    )
    return [
        _version_payload(doc.id, doc.to_dict() or {})
        async for doc in query.stream()
    ]


async def get_version(db: AsyncClient, version_id: str) -> dict[str, Any] | None:
    snap = await prompt_versions_ref(db).document(version_id).get()
    if not snap.exists:
        return None
    return _version_payload(version_id, snap.to_dict() or {})


async def get_deployment(db: AsyncClient) -> dict[str, Any]:
    snap = await prompt_deployments_ref(db).document(CURRENT_DEPLOYMENT_ID).get()
    if not snap.exists:
        return {
            "environment": settings.environment,
            "version_id": None,
            "deployed_by": None,
            "deployed_at": None,
        }
    data = snap.to_dict() or {}
    return {
        "environment": data.get("environment") or settings.environment,
        "version_id": data.get("version_id"),
        "deployed_by": data.get("deployed_by"),
        "deployed_at": _iso(data.get("deployed_at")),
    }


async def deploy_version(
    db: AsyncClient,
    *,
    version_id: str,
    deployed_by: str,
) -> dict[str, Any]:
    version = await get_version(db, version_id)
    if version is None:
        raise ValueError(f"prompt version not found: {version_id}")

    now = datetime.now(UTC)
    await prompt_deployments_ref(db).document(CURRENT_DEPLOYMENT_ID).set(
        {
            "environment": settings.environment,
            "version_id": version_id,
            "deployed_by": deployed_by,
            "deployed_at": now,
        }
    )
    await prompt_versions_ref(db).document(version_id).update({"status": "production"})
    return {
        "environment": settings.environment,
        "version_id": version_id,
        "deployed_by": deployed_by,
        "deployed_at": now.isoformat(),
    }


async def get_active_prompt(db: AsyncClient) -> tuple[str, str | None]:
    config, version_id = await get_active_config(db)
    return str(config["system_prompt"]), version_id


async def get_active_config(db: AsyncClient) -> tuple[dict[str, Any], str | None]:
    deployment = await get_deployment(db)
    version_id = deployment.get("version_id")
    if not version_id:
        return default_config(), None
    version = await get_version(db, version_id)
    if version is None:
        return default_config(), None
    return normalize_config(version), str(version_id)


async def log_prompt_test(
    db: AsyncClient,
    *,
    actor: str,
    message: str,
    response: str,
    version_id: str | None,
    prompt: str,
    config: dict[str, Any] | None,
    diary_content: str | None,
    model: str,
) -> str:
    log_id = str(uuid.uuid4())
    await prompt_test_logs_ref(db).document(log_id).set(
        {
            "actor": actor,
            "message": message,
            "response": response,
            "version_id": version_id,
            "prompt": prompt,
            "config": config,
            "diary_content": diary_content,
            "model": model,
            "environment": settings.environment,
            "created_at": datetime.now(UTC),
        }
    )
    return log_id
