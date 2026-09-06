"""Authenticated remote MCP server for Coach Studio administration."""

from __future__ import annotations

import hashlib
import json
import logging
from collections.abc import Awaitable, Callable
from typing import Any

from mcp.server.auth.middleware.auth_context import get_access_token
from mcp.server.auth.settings import AuthSettings
from mcp.server.fastmcp import FastMCP
from mcp.server.fastmcp.exceptions import ToolError
from mcp.types import ToolAnnotations
from pydantic import AnyHttpUrl, ValidationError
from starlette.requests import Request
from starlette.responses import JSONResponse

from app.config import settings
from app.mcp_auth import OIDCJWTVerifier
from app.models.admin import EditablePromptConfig, PromptVersionCreateRequest
from app.services import mcp_backend_client

logger = logging.getLogger(__name__)
def _config_hash(config: dict[str, Any]) -> str:
    payload = json.dumps(
        config,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(payload.encode()).hexdigest()


def _identity() -> tuple[str, str]:
    access_token = get_access_token()
    if access_token is None or not access_token.claims:
        raise ToolError("認証済みユーザーを確認できません")
    claims = access_token.claims
    email = str(
        claims.get(settings.mcp_email_claim) or claims.get("email") or ""
    ).strip().lower()
    if email not in settings.mcp_email_allowlist:
        raise ToolError("このMCPを使用する権限がありません")
    return str(access_token.subject or ""), email


async def _audit(
    *,
    tool: str,
    outcome: str,
    details: dict[str, Any],
    error: str | None = None,
) -> None:
    subject, email = _identity()
    payload = {
        "actor_subject": subject,
        "actor_email": email,
        "tool": tool,
        "outcome": outcome,
        "details": details,
        "error": error,
        "environment": settings.environment,
    }
    logger.info("coach_mcp_audit %s", payload)


async def _audited[T](
    tool: str,
    details: dict[str, Any],
    operation: Callable[[], Awaitable[T]],
) -> T:
    try:
        result = await operation()
    except Exception as exc:
        await _audit(
            tool=tool,
            outcome="error",
            details=details,
            error=type(exc).__name__,
        )
        raise
    await _audit(tool=tool, outcome="success", details=details)
    return result


token_verifier = OIDCJWTVerifier(
    issuer=settings.mcp_oauth_issuer,
    audience=settings.mcp_oauth_audience,
    allowed_emails=settings.mcp_email_allowlist,
    required_scope=settings.mcp_required_scope,
    email_claim=settings.mcp_email_claim,
    email_verified_claim=settings.mcp_email_verified_claim,
    jwks_uri=settings.mcp_oauth_jwks_uri,
)

mcp = FastMCP(
    name="Treow Coach Studio",
    instructions=(
        "Treowのコーチ設定を確認、検証、テストし、版として保存する管理ツールです。"
        "開発環境への適用は明示確認がある場合だけ実行してください。"
        "本番環境への適用はこのサーバーからはできません。"
    ),
    token_verifier=token_verifier,
    auth=AuthSettings(
        issuer_url=AnyHttpUrl(settings.mcp_oauth_issuer),
        resource_server_url=AnyHttpUrl(settings.mcp_public_url),
        required_scopes=[settings.mcp_required_scope],
    ),
    host="0.0.0.0",
    port=8080,
    streamable_http_path="/mcp",
    json_response=True,
    stateless_http=True,
)


@mcp.custom_route("/health", methods=["GET"])  # type: ignore[untyped-decorator]
async def health(_: Request) -> JSONResponse:
    return JSONResponse({"status": "ok", "service": "cycle-coach-mcp"})


@mcp.tool(
    title="現在のコーチ設定を取得",
    description="開発環境で現在使用されているコーチ設定と版を取得します。",
    annotations=ToolAnnotations(readOnlyHint=True, openWorldHint=False),
)
async def coach_get_current_config() -> dict[str, Any]:
    async def operation() -> dict[str, Any]:
        _, email = _identity()
        current = await mcp_backend_client.request(
            "GET",
            "/internal/mcp/prompts/current",
            actor=email,
        )
        config = current["config"]
        version_id = current.get("version_id")
        return {
            "environment": settings.environment,
            "version_id": version_id,
            "source": "saved_version" if version_id else "application_default",
            "config_hash": _config_hash(config),
            "config": config,
        }

    return await _audited("coach_get_current_config", {}, operation)


@mcp.tool(
    title="保存済みの版を一覧表示",
    description="最近保存されたコーチ設定の版を一覧表示します。",
    annotations=ToolAnnotations(readOnlyHint=True, openWorldHint=False),
)
async def coach_list_versions(limit: int = 20) -> dict[str, Any]:
    safe_limit = max(1, min(limit, 50))

    async def operation() -> dict[str, Any]:
        _, email = _identity()
        result = await mcp_backend_client.request(
            "GET",
            "/internal/mcp/prompts/versions",
            actor=email,
            params={"limit": safe_limit},
        )
        versions = result["versions"]
        return {
            "versions": [
                {
                    "version_id": item["version_id"],
                    "title": item["title"],
                    "notes": item["notes"],
                    "status": item["status"],
                    "created_by": item["created_by"],
                    "created_at": item["created_at"],
                    "config_hash": _config_hash(item["config"]),
                }
                for item in versions
            ]
        }

    return await _audited("coach_list_versions", {"limit": safe_limit}, operation)


@mcp.tool(
    title="保存済みの版を取得",
    description="指定した版のコーチ設定を取得します。",
    annotations=ToolAnnotations(readOnlyHint=True, openWorldHint=False),
)
async def coach_get_version(version_id: str) -> dict[str, Any]:
    async def operation() -> dict[str, Any]:
        _, email = _identity()
        try:
            return await mcp_backend_client.request(
                "GET",
                f"/internal/mcp/prompts/versions/{version_id}",
                actor=email,
            )
        except mcp_backend_client.MCPBackendError as exc:
            raise ToolError(str(exc)) from exc

    return await _audited(
        "coach_get_version", {"version_id": version_id}, operation
    )


@mcp.tool(
    title="コーチ設定の変更を検証",
    description=(
        "設定を保存せずに検証し、現在の設定から変更された項目を返します。"
        "保存前に必ず使用してください。"
    ),
    annotations=ToolAnnotations(readOnlyHint=True, openWorldHint=False),
)
async def coach_validate_changes(config: dict[str, Any]) -> dict[str, Any]:
    async def operation() -> dict[str, Any]:
        try:
            validated = EditablePromptConfig.model_validate(config).model_dump()
        except ValidationError as exc:
            raise ToolError(f"設定の検証に失敗しました: {exc}") from exc
        _, email = _identity()
        current_data = await mcp_backend_client.request(
            "GET",
            "/internal/mcp/prompts/current",
            actor=email,
        )
        current = current_data["config"]
        version_id = current_data.get("version_id")
        changed_fields = sorted(
            key for key in validated if validated.get(key) != current.get(key)
        )
        return {
            "valid": True,
            "base_version_id": version_id,
            "changed_fields": changed_fields,
            "config_hash": _config_hash(validated),
        }

    return await _audited(
        "coach_validate_changes", {"config_hash": _config_hash(config)}, operation
    )


@mcp.tool(
    title="コーチ設定をテスト",
    description="設定を保存・適用せず、1件の入力に対するコーチの返答をテストします。",
    annotations=ToolAnnotations(readOnlyHint=True, openWorldHint=True),
)
async def coach_test_config(
    message: str,
    config: dict[str, Any],
    diary_content: str | None = None,
    history: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    async def operation() -> dict[str, Any]:
        try:
            validated = EditablePromptConfig.model_validate(config).model_dump()
        except ValidationError as exc:
            raise ToolError(f"設定の検証に失敗しました: {exc}") from exc
        _, email = _identity()
        return await mcp_backend_client.request(
            "POST",
            "/internal/mcp/prompts/test",
            actor=email,
            json_body={
                "message": message,
                "prompt": validated["system_prompt"],
                "config": validated,
                "diary_content": diary_content,
                "history": history,
            },
        )

    return await _audited(
        "coach_test_config",
        {"config_hash": _config_hash(config), "message_length": len(message)},
        operation,
    )


@mcp.tool(
    title="コーチ設定を新しい版として保存",
    description="検証済みのコーチ設定を新しい下書き版として保存します。適用はしません。",
    annotations=ToolAnnotations(
        readOnlyHint=False,
        destructiveHint=False,
        idempotentHint=False,
        openWorldHint=False,
    ),
)
async def coach_save_draft(
    title: str,
    config: dict[str, Any],
    notes: str | None = None,
) -> dict[str, Any]:
    async def operation() -> dict[str, Any]:
        try:
            body = PromptVersionCreateRequest(
                title=title,
                prompt=str(config.get("system_prompt", "")),
                config=EditablePromptConfig.model_validate(config),
                notes=notes,
            )
        except ValidationError as exc:
            raise ToolError(f"設定の検証に失敗しました: {exc}") from exc
        _, email = _identity()
        return await mcp_backend_client.request(
            "POST",
            "/internal/mcp/prompts/versions",
            actor=email,
            json_body=body.model_dump(),
        )

    return await _audited(
        "coach_save_draft",
        {"title": title, "config_hash": _config_hash(config)},
        operation,
    )


@mcp.tool(
    title="保存済みの版を開発環境へ適用",
    description=(
        "指定した版を開発環境へ適用します。confirmationには"
        "『DEPLOY <version_id>』を完全一致で指定してください。本番には適用できません。"
    ),
    annotations=ToolAnnotations(
        readOnlyHint=False,
        destructiveHint=True,
        idempotentHint=True,
        openWorldHint=False,
    ),
)
async def coach_deploy_to_dev(version_id: str, confirmation: str) -> dict[str, Any]:
    async def operation() -> dict[str, Any]:
        if settings.environment != "dev":
            raise ToolError("このMCPから本番環境へ適用することはできません")
        if confirmation != f"DEPLOY {version_id}":
            raise ToolError("確認文字列が一致しないため、適用しませんでした")
        _, email = _identity()
        try:
            return await mcp_backend_client.request(
                "POST",
                "/internal/mcp/prompts/deployment",
                actor=email,
                json_body={"version_id": version_id},
            )
        except mcp_backend_client.MCPBackendError as exc:
            raise ToolError(str(exc)) from exc

    return await _audited(
        "coach_deploy_to_dev", {"version_id": version_id}, operation
    )


app = mcp.streamable_http_app()
