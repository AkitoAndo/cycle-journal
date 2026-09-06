"""Coach endpoint - AI coaching with Vertex AI Claude."""

import asyncio
import json
import logging
import uuid
from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from google.cloud.firestore import AsyncClient

from app.config import settings
from app.dependencies import get_current_user, get_firestore
from app.models.coach import CoachData, CoachMetadata, CoachRequest
from app.services import (
    ai_usage_service,
    coach_phase_service,
    coach_response_lint,
    coach_service,
    context_service,
    prompt_service,
)
from app.services.coach_graph import run_coach_flow
from app.services.firestore_client import sessions_ref, tasks_ref

router = APIRouter(tags=["Coach"])
logger = logging.getLogger("app.coach")


def _validate_input_size(message: str) -> None:
    if len(message) > settings.coach_input_max_chars:
        raise HTTPException(
            status_code=400,
            detail=(
                f"message too long: {len(message)} chars "
                f"(limit {settings.coach_input_max_chars})"
            ),
        )


@router.post("/coach")
async def chat(
    body: CoachRequest,
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """ユーザーのメッセージに対してAIコーチが応答."""
    _validate_input_size(body.message)
    now = datetime.now(UTC)
    session_id, session_doc, session_data = await _ensure_session(
        db, user_id, body, now
    )
    effective_diary_content = await _remember_diary_context(
        session_doc,
        session_data,
        body.diary_content,
        now,
    )
    prompt_config, prompt_version_id = await prompt_service.get_active_config(db)
    boundary_route = coach_phase_service.detect_boundary_route(body.message)
    if boundary_route:
        visible_response_text = coach_phase_service.boundary_response(boundary_route)
        coach_control = coach_phase_service.boundary_control(
            session_data.get("coach_state"),
            boundary_route,
        )
        await _persist_fixed_coach_response(
            session_doc=session_doc,
            session_data=session_data,
            message=body.message,
            visible_response_text=visible_response_text,
            coach_control=coach_control,
            prompt_version_id=prompt_version_id,
            user_now=now,
        )
        return {
            "data": CoachData(
                message=visible_response_text,
                session_id=session_id,
                metadata=CoachMetadata(
                    stage=settings.environment,
                    model="server-boundary",
                    cycle_element=body.context.cycle_element
                    if body.context
                    else None,
                    detected_emotion=None,
                ),
            )
        }

    # 過去のメッセージ履歴を取得
    messages_ref = session_doc.collection("messages")
    history_query = messages_ref.order_by("created_at").limit(
        settings.coach_context_history_max_messages
    )
    history_docs = [doc async for doc in history_query.stream()]
    history = context_service.trim_history(
        [
            {"role": doc.get("role"), "content": doc.get("content")}
            for doc in history_docs
        ]
    )

    memory_context_block = await context_service.build_context_block(
        db,
        user_id=user_id,
        current_session_id=session_id,
    )
    phase_context_block = coach_phase_service.build_phase_context(
        session_data,
        config=prompt_config,
    )
    context_block = context_service.join_context_blocks(
        [memory_context_block, phase_context_block]
    )

    estimate = ai_usage_service.estimate_coach_request(
        message=body.message,
        history=history,
        diary_content=effective_diary_content,
        context_block=context_block,
    )
    await ai_usage_service.reserve_monthly_budget(
        db,
        user_id=user_id,
        estimate=estimate,
    )

    system_prompt = str(prompt_config["system_prompt"])

    generation = await _generate_linted_coach_response(
        body=body,
        history=history,
        diary_content=effective_diary_content,
        context_block=context_block,
        memory_context_block=memory_context_block,
        system_prompt=system_prompt,
        prompt_config=prompt_config,
        raw_state=session_data.get("coach_state"),
    )
    visible_response_text = str(generation["visible_response_text"])
    coach_control = generation.get("coach_control")
    detected_emotion = generation.get("detected_emotion")
    response_cycle_element = generation.get("response_cycle_element")
    coach_lint_regenerated = bool(generation.get("coach_lint_regenerated"))
    coach_lint_violations = generation.get("coach_lint_violations")

    # ユーザーメッセージを保存
    user_msg_id = str(uuid.uuid4())
    await messages_ref.document(user_msg_id).set(
        {
            "role": "user",
            "content": body.message,
            "metadata": None,
            "created_at": now,
        }
    )

    # アシスタント応答を保存
    assistant_msg_id = str(uuid.uuid4())
    assistant_now = datetime.now(UTC)
    coach_state = coach_phase_service.apply_control_state(
        session_data.get("coach_state"),
        coach_control,
        now=assistant_now,
    )
    created_task_id = await _maybe_create_triage_task(
        db=db,
        user_id=user_id,
        session_id=session_id,
        session_data=session_data,
        coach_control=coach_control,
        cycle_element=body.context.cycle_element.value
        if body.context and body.context.cycle_element
        else None,
        now=assistant_now,
    )
    if created_task_id:
        candidate = coach_phase_service.task_write_candidate(
            session_data.get("coach_state"),
            coach_control,
        )
        if candidate:
            coach_state = coach_phase_service.attach_task_to_state(
                coach_state,
                item_text=candidate["title"],
                task_id=created_task_id,
            )
    await messages_ref.document(assistant_msg_id).set(
        {
            "role": "assistant",
            "content": visible_response_text,
            "metadata": {
                "model": settings.claude_model,
                "prompt_version_id": prompt_version_id,
                "coach_control": coach_control,
                "created_task_id": created_task_id,
                "coach_lint_regenerated": coach_lint_regenerated,
                "coach_lint_violations": coach_lint_violations,
            },
            "created_at": assistant_now,
        }
    )

    # セッションのメッセージ数を更新
    base_message_count = int(session_data.get("message_count", 0) or 0)
    next_message_count = base_message_count + 2
    await session_doc.update(
        {
            "message_count": next_message_count,
            "last_message_at": assistant_now,
            "updated_at": assistant_now,
            "coach_state": coach_state,
        }
    )
    summary_session_data = {**session_data, "message_count": next_message_count}
    await _try_update_summary(
        session_doc=session_doc,
        session_data=summary_session_data,
        messages=[
            *history,
            {"role": "user", "content": body.message},
            {"role": "assistant", "content": visible_response_text},
        ],
        diary_context=effective_diary_content,
        prompt_config=prompt_config,
        now=assistant_now,
    )

    # Treow要素: LangGraphの判定結果 > リクエストの指定
    final_cycle_element = response_cycle_element or (
        body.context.cycle_element if body.context else None
    )

    return {
        "data": CoachData(
            message=visible_response_text,
            session_id=session_id,
            metadata=CoachMetadata(
                stage=settings.environment,
                model=settings.claude_model,
                cycle_element=final_cycle_element,
                detected_emotion=detected_emotion,
            ),
        )
    }


async def _ensure_session(
    db: AsyncClient,
    user_id: str,
    body: CoachRequest,
    now: datetime,
) -> tuple[str, object, dict]:
    ref = sessions_ref(db)
    session_id = body.session_id or str(uuid.uuid4())
    session_doc = ref.document(session_id)
    snap = await session_doc.get()
    if snap.exists and snap.get("user_id") != user_id:
        session_id = str(uuid.uuid4())
        session_doc = ref.document(session_id)
        snap = await session_doc.get()
    if not snap.exists:
        cycle_element = (
            body.context.cycle_element.value
            if body.context and body.context.cycle_element
            else None
        )
        diary_context = context_service.sanitize_diary_context(body.diary_content)
        session_data = {
            "user_id": user_id,
            "title": None,
            "cycle_element": cycle_element,
            "diary_context": diary_context,
            "has_diary_context": diary_context is not None,
            "message_count": 0,
            "last_message_at": now,
            "created_at": now,
            "updated_at": now,
        }
        await session_doc.set(session_data)
        return session_id, session_doc, session_data
    return session_id, session_doc, snap.to_dict() or {}


async def _remember_diary_context(
    session_doc,
    session_data: dict,
    diary_content: str | None,
    now: datetime,
) -> str | None:
    if diary_content is None:
        return session_data.get("diary_context")

    diary_context = context_service.sanitize_diary_context(diary_content)
    if diary_context == session_data.get("diary_context"):
        return diary_context

    await session_doc.update(
        {
            "diary_context": diary_context,
            "has_diary_context": diary_context is not None,
            "updated_at": now,
        }
    )
    session_data["diary_context"] = diary_context
    session_data["has_diary_context"] = diary_context is not None
    return diary_context


async def _generate_coach_response(
    *,
    body: CoachRequest,
    history: list[dict[str, str]],
    diary_content: str | None,
    context_block: str | None,
    system_prompt: str,
    prompt_config: dict[str, Any],
) -> dict[str, Any]:
    if bool(prompt_config.get("use_langgraph")):
        flow_result = await run_coach_flow(
            user_message=body.message,
            history=history,
            diary_content=diary_content,
            context_block=context_block,
            system_prompt=system_prompt,
            config=prompt_config,
        )
        return {
            "response_text": flow_result["response"],
            "detected_emotion": flow_result.get("detected_emotion"),
            "response_cycle_element": flow_result.get("cycle_element"),
        }

    response_text = await coach_service.chat(
        user_message=body.message,
        history=history,
        diary_content=diary_content,
        context_block=context_block,
        system_prompt=system_prompt,
        config=prompt_config,
    )
    return {
        "response_text": response_text,
        "detected_emotion": None,
        "response_cycle_element": None,
    }


async def _generate_linted_coach_response(
    *,
    body: CoachRequest,
    history: list[dict[str, str]],
    diary_content: str | None,
    context_block: str | None,
    memory_context_block: str | None,
    system_prompt: str,
    prompt_config: dict[str, Any],
    raw_state: Any,
) -> dict[str, Any]:
    generation = await _generate_coach_response(
        body=body,
        history=history,
        diary_content=diary_content,
        context_block=context_block,
        system_prompt=system_prompt,
        prompt_config=prompt_config,
    )
    response_text = str(generation["response_text"])
    visible_text, coach_control = coach_phase_service.extract_control_block(
        response_text
    )
    vocabulary_sources = _vocabulary_sources(
        body=body,
        history=history,
        diary_content=diary_content,
        memory_context_block=memory_context_block,
    )
    lint_violations = coach_response_lint.lint_visible_response(
        visible_text,
        raw_state=raw_state,
        control=coach_control,
        vocabulary_sources=vocabulary_sources,
        enable_vocabulary_lint=bool(
            prompt_config.get("coach_vocabulary_lint_enabled") is True
        ),
    )
    regenerated = False

    if lint_violations:
        retry_context_block = context_service.join_context_blocks(
            [
                context_block,
                coach_response_lint.build_retry_context(lint_violations),
            ]
        )
        generation = await _generate_coach_response(
            body=body,
            history=history,
            diary_content=diary_content,
            context_block=retry_context_block,
            system_prompt=system_prompt,
            prompt_config=prompt_config,
        )
        response_text = str(generation["response_text"])
        visible_text, coach_control = coach_phase_service.extract_control_block(
            response_text
        )
        regenerated = True
        lint_violations = coach_response_lint.lint_visible_response(
            visible_text,
            raw_state=raw_state,
            control=coach_control,
            vocabulary_sources=vocabulary_sources,
            enable_vocabulary_lint=bool(
                prompt_config.get("coach_vocabulary_lint_enabled") is True
            ),
        )

    return {
        **generation,
        "visible_response_text": visible_text,
        "coach_control": coach_control,
        "coach_lint_regenerated": regenerated,
        "coach_lint_violations": lint_violations,
    }


def _vocabulary_sources(
    *,
    body: CoachRequest,
    history: list[dict[str, str]],
    diary_content: str | None,
    memory_context_block: str | None,
) -> list[str | None]:
    return [
        *(item["content"] for item in history if item.get("role") == "user"),
        diary_content,
        memory_context_block,
        body.message,
    ]


async def _try_update_summary(
    *,
    session_doc,
    session_data: dict,
    messages: list[dict[str, str]],
    diary_context: str | None,
    prompt_config: dict,
    now: datetime,
) -> None:
    try:
        await context_service.maybe_update_session_summary(
            session_doc,
            session_data=session_data,
            messages=messages,
            diary_context=diary_context,
            config=prompt_config,
            now=now,
        )
    except Exception as exc:  # noqa: BLE001
        logger.warning("coach summary update failed: %s", exc)


async def _persist_fixed_coach_response(
    *,
    session_doc,
    session_data: dict,
    message: str,
    visible_response_text: str,
    coach_control: dict,
    prompt_version_id: str | None,
    user_now: datetime,
) -> None:
    """Persist a server-routed coach response that did not call a model."""
    messages_ref = session_doc.collection("messages")
    user_msg_id = str(uuid.uuid4())
    await messages_ref.document(user_msg_id).set(
        {
            "role": "user",
            "content": message,
            "metadata": None,
            "created_at": user_now,
        }
    )

    assistant_now = datetime.now(UTC)
    assistant_msg_id = str(uuid.uuid4())
    coach_state = coach_phase_service.apply_control_state(
        session_data.get("coach_state"),
        coach_control,
        now=assistant_now,
    )
    await messages_ref.document(assistant_msg_id).set(
        {
            "role": "assistant",
            "content": visible_response_text,
            "metadata": {
                "model": "server-boundary",
                "prompt_version_id": prompt_version_id,
                "coach_control": coach_control,
            },
            "created_at": assistant_now,
        }
    )

    base_message_count = int(session_data.get("message_count", 0) or 0)
    await session_doc.update(
        {
            "message_count": base_message_count + 2,
            "last_message_at": assistant_now,
            "updated_at": assistant_now,
            "coach_state": coach_state,
        }
    )


async def _maybe_create_triage_task(
    *,
    db: AsyncClient,
    user_id: str,
    session_id: str,
    session_data: dict,
    coach_control: dict[str, Any] | None,
    cycle_element: str | None,
    now: datetime,
) -> str | None:
    candidate = coach_phase_service.task_write_candidate(
        session_data.get("coach_state"),
        coach_control,
    )
    if not candidate:
        return None

    task_id = str(uuid.uuid4())
    task_data = {
        "user_id": user_id,
        "title": candidate["title"],
        "description": None,
        "status": "pending",
        "session_id": session_id,
        "cycle_element": cycle_element,
        "due_date": None,
        "completed_at": None,
        "source": "coach_triage",
        "created_at": now,
        "updated_at": now,
    }
    await tasks_ref(db).document(task_id).set(task_data)
    return task_id


@router.post("/coach/stream")
async def chat_stream(
    body: CoachRequest,
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """Server-Sent Events で chunk 単位に応答を返す."""
    _validate_input_size(body.message)
    now = datetime.now(UTC)
    session_id, session_doc, session_data = await _ensure_session(
        db, user_id, body, now
    )
    effective_diary_content = await _remember_diary_context(
        session_doc,
        session_data,
        body.diary_content,
        now,
    )
    prompt_config, prompt_version_id = await prompt_service.get_active_config(db)
    boundary_route = coach_phase_service.detect_boundary_route(body.message)
    if boundary_route:
        visible_response_text = coach_phase_service.boundary_response(boundary_route)
        coach_control = coach_phase_service.boundary_control(
            session_data.get("coach_state"),
            boundary_route,
        )
        await _persist_fixed_coach_response(
            session_doc=session_doc,
            session_data=session_data,
            message=body.message,
            visible_response_text=visible_response_text,
            coach_control=coach_control,
            prompt_version_id=prompt_version_id,
            user_now=now,
        )

        async def fixed_event_source():
            yield f"event: session\ndata: {json.dumps({'session_id': session_id})}\n\n"
            yield f"data: {json.dumps({'chunk': visible_response_text})}\n\n"
            yield "event: done\ndata: {}\n\n"

        return StreamingResponse(fixed_event_source(), media_type="text/event-stream")

    messages_ref = session_doc.collection("messages")
    history_query = messages_ref.order_by("created_at").limit(
        settings.coach_context_history_max_messages
    )
    history_docs = [doc async for doc in history_query.stream()]
    history = context_service.trim_history(
        [
            {"role": doc.get("role"), "content": doc.get("content")}
            for doc in history_docs
        ]
    )
    memory_context_block = await context_service.build_context_block(
        db,
        user_id=user_id,
        current_session_id=session_id,
    )
    phase_context_block = coach_phase_service.build_phase_context(
        session_data,
        config=prompt_config,
    )
    context_block = context_service.join_context_blocks(
        [memory_context_block, phase_context_block]
    )
    system_prompt = str(prompt_config["system_prompt"])

    estimate = ai_usage_service.estimate_coach_request(
        message=body.message,
        history=history,
        diary_content=effective_diary_content,
        context_block=context_block,
    )
    await ai_usage_service.reserve_monthly_budget(
        db,
        user_id=user_id,
        estimate=estimate,
    )

    # ユーザーメッセージは streaming 開始前に保存（途中で失敗しても残す）
    user_msg_id = str(uuid.uuid4())
    await messages_ref.document(user_msg_id).set(
        {"role": "user", "content": body.message, "metadata": None, "created_at": now}
    )

    async def event_source():
        # SSE 起動メッセージ
        yield f"event: session\ndata: {json.dumps({'session_id': session_id})}\n\n"
        generation = None
        try:
            async with asyncio.timeout(settings.coach_stream_timeout_seconds):
                generation = await _generate_linted_coach_response(
                    body=body,
                    history=history,
                    diary_content=effective_diary_content,
                    context_block=context_block,
                    memory_context_block=memory_context_block,
                    system_prompt=system_prompt,
                    prompt_config=prompt_config,
                    raw_state=session_data.get("coach_state"),
                )
            visible_response_text = str(generation["visible_response_text"])
            if visible_response_text:
                yield f"data: {json.dumps({'chunk': visible_response_text})}\n\n"
        except TimeoutError:
            logger.warning("coach stream timeout", extra={"session_id": session_id})
            yield f"event: error\ndata: {json.dumps({'reason': 'timeout'})}\n\n"
        except Exception as exc:  # noqa: BLE001
            logger.exception("coach stream failed", extra={"session_id": session_id})
            yield (
                "event: error\ndata: "
                + json.dumps({"reason": "internal", "detail": str(exc)[:200]})
                + "\n\n"
            )
        finally:
            if generation:
                visible_response_text = str(generation["visible_response_text"])
                coach_control = generation.get("coach_control")
                coach_state = coach_phase_service.apply_control_state(
                    session_data.get("coach_state"),
                    coach_control,
                    now=datetime.now(UTC),
                )
                assistant_now = datetime.now(UTC)
                created_task_id = await _maybe_create_triage_task(
                    db=db,
                    user_id=user_id,
                    session_id=session_id,
                    session_data=session_data,
                    coach_control=coach_control,
                    cycle_element=body.context.cycle_element.value
                    if body.context and body.context.cycle_element
                    else None,
                    now=assistant_now,
                )
                if created_task_id:
                    candidate = coach_phase_service.task_write_candidate(
                        session_data.get("coach_state"),
                        coach_control,
                    )
                    if candidate:
                        coach_state = coach_phase_service.attach_task_to_state(
                            coach_state,
                            item_text=candidate["title"],
                            task_id=created_task_id,
                        )
                assistant_msg_id = str(uuid.uuid4())
                await messages_ref.document(assistant_msg_id).set(
                    {
                        "role": "assistant",
                        "content": visible_response_text,
                        "metadata": {
                            "model": settings.claude_model,
                            "streamed": True,
                            "prompt_version_id": prompt_version_id,
                            "coach_control": coach_control,
                            "created_task_id": created_task_id,
                            "coach_lint_regenerated": bool(
                                generation.get("coach_lint_regenerated")
                            ),
                            "coach_lint_violations": generation.get(
                                "coach_lint_violations"
                            ),
                        },
                        "created_at": assistant_now,
                    }
                )
                base_message_count = int(session_data.get("message_count", 0) or 0)
                next_message_count = base_message_count + 2
                await session_doc.update(
                    {
                        "message_count": next_message_count,
                        "last_message_at": assistant_now,
                        "updated_at": assistant_now,
                        "coach_state": coach_state,
                    }
                )
                summary_session_data = {
                    **session_data,
                    "message_count": next_message_count,
                }
                await _try_update_summary(
                    session_doc=session_doc,
                    session_data=summary_session_data,
                    messages=[
                        *history,
                        {"role": "user", "content": body.message},
                        {"role": "assistant", "content": visible_response_text},
                    ],
                    diary_context=effective_diary_content,
                    prompt_config=prompt_config,
                    now=assistant_now,
                )
            yield "event: done\ndata: {}\n\n"

    return StreamingResponse(event_source(), media_type="text/event-stream")


async def _with_timeout(agen, seconds: int):
    """async generator に総時間タイムアウトをかける."""
    queue: asyncio.Queue = asyncio.Queue()
    sentinel = object()

    async def pump():
        try:
            async for item in agen:
                await queue.put(item)
        finally:
            await queue.put(sentinel)

    task = asyncio.create_task(pump())
    try:
        async with asyncio.timeout(seconds):
            while True:
                item = await queue.get()
                if item is sentinel:
                    return
                yield item
    finally:
        if not task.done():
            task.cancel()
