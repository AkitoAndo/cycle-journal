"""Shared Coach Studio operations used by HTTP admin and MCP surfaces."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from google.cloud.firestore import AsyncClient

from app.models.admin import EditablePromptConfig, PromptTestRequest
from app.services import coach_service, prompt_service


@dataclass(frozen=True)
class PromptTestResult:
    response: str
    version_id: str | None
    prompt: str
    config: dict[str, Any]
    model: str


async def run_prompt_test(
    db: AsyncClient,
    body: PromptTestRequest,
) -> PromptTestResult:
    """Resolve and execute one prompt test without mutating process settings."""
    if not body.prompt and not body.version_id:
        raise ValueError("prompt or version_id is required")

    version_id = body.version_id
    prompt = body.prompt
    config = body.config.model_dump() if body.config else None
    if version_id:
        version = await prompt_service.get_version(db, version_id)
        if version is None:
            raise LookupError("prompt version not found")
        prompt = str(version["prompt"])
        config = version["config"]

    assert prompt is not None
    if config is None:
        config = prompt_service.normalize_config({"prompt": prompt})
    # Re-validate stored or normalized configurations at the execution boundary.
    config = EditablePromptConfig.model_validate(config).model_dump()

    use_langgraph = bool(config.get("use_langgraph"))
    use_gemini_fallback = bool(config.get("use_gemini_fallback"))
    if use_langgraph:
        from app.services.coach_graph import run_coach_flow

        flow_result = await run_coach_flow(
            user_message=body.message,
            history=body.history,
            diary_content=body.diary_content,
            system_prompt=prompt,
            config=config,
        )
        response = flow_result["response"]
    else:
        response = await coach_service.chat(
            user_message=body.message,
            history=body.history,
            diary_content=body.diary_content,
            system_prompt=prompt,
            config=config,
        )

    model_key = "gemini_model_coach" if use_gemini_fallback else "claude_model_coach"
    return PromptTestResult(
        response=response,
        version_id=version_id,
        prompt=prompt,
        config=config,
        model=str(config[model_key]),
    )
