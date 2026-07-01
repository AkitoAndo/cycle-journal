"""Coach endpoint - AI coaching with Vertex AI Claude."""

import asyncio
import json
import logging
import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from google.cloud.firestore import AsyncClient

from app.config import settings
from app.dependencies import get_current_user, get_firestore
from app.models.coach import CoachData, CoachMetadata, CoachRequest
from app.services import ai_usage_service, coach_service
from app.services.coach_graph import run_coach_flow
from app.services.firestore_client import sessions_ref

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
    ref = sessions_ref(db)

    # セッション取得 or 新規作成
    if body.session_id:
        session_doc = ref.document(body.session_id)
        session_snap = await session_doc.get()
        if not session_snap.exists or session_snap.get("user_id") != user_id:
            # セッションが存在しないか別ユーザーの場合は新規作成
            session_id = str(uuid.uuid4())
            session_doc = ref.document(session_id)
        else:
            session_id = body.session_id
    else:
        session_id = str(uuid.uuid4())
        session_doc = ref.document(session_id)

    # セッションが未作成の場合は作成
    session_snap = await session_doc.get()
    if not session_snap.exists:
        cycle_element = (
            body.context.cycle_element.value
            if body.context and body.context.cycle_element
            else None
        )
        await session_doc.set(
            {
                "user_id": user_id,
                "title": None,
                "cycle_element": cycle_element,
                "has_diary_context": body.diary_content is not None,
                "message_count": 0,
                "last_message_at": now,
                "created_at": now,
                "updated_at": now,
            }
        )

    # 過去のメッセージ履歴を取得
    messages_ref = session_doc.collection("messages")
    history_query = messages_ref.order_by("created_at").limit(50)
    history_docs = [doc async for doc in history_query.stream()]
    history = [
        {"role": doc.get("role"), "content": doc.get("content")}
        for doc in history_docs
    ]

    estimate = ai_usage_service.estimate_coach_request(
        message=body.message,
        history=history,
        diary_content=body.diary_content,
    )
    await ai_usage_service.reserve_monthly_budget(
        db,
        user_id=user_id,
        estimate=estimate,
    )

    # コーチ応答を取得（LangGraph or シンプル呼び出し）
    detected_emotion = None
    response_cycle_element = None

    if settings.use_langgraph:
        flow_result = await run_coach_flow(
            user_message=body.message,
            history=history,
            diary_content=body.diary_content,
        )
        response_text = flow_result["response"]
        detected_emotion = flow_result.get("detected_emotion")
        response_cycle_element = flow_result.get("cycle_element")
    else:
        response_text = await coach_service.chat(
            user_message=body.message,
            history=history,
            diary_content=body.diary_content,
        )

    # ユーザーメッセージを保存
    user_msg_id = str(uuid.uuid4())
    await messages_ref.document(user_msg_id).set({
        "role": "user",
        "content": body.message,
        "metadata": None,
        "created_at": now,
    })

    # アシスタント応答を保存
    assistant_msg_id = str(uuid.uuid4())
    assistant_now = datetime.now(UTC)
    await messages_ref.document(assistant_msg_id).set({
        "role": "assistant",
        "content": response_text,
        "metadata": {
            "model": settings.claude_model,
        },
        "created_at": assistant_now,
    })

    # セッションのメッセージ数を更新
    session_data = (await session_doc.get()).to_dict() or {}
    await session_doc.update({
        "message_count": session_data.get("message_count", 0) + 2,
        "last_message_at": assistant_now,
        "updated_at": assistant_now,
    })

    # Cycle要素: LangGraphの判定結果 > リクエストの指定
    final_cycle_element = (
        response_cycle_element
        or (body.context.cycle_element if body.context else None)
    )

    return {
        "data": CoachData(
            message=response_text,
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
) -> tuple[str, object]:
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
        await session_doc.set(
            {
                "user_id": user_id,
                "title": None,
                "cycle_element": cycle_element,
                "has_diary_context": body.diary_content is not None,
                "message_count": 0,
                "last_message_at": now,
                "created_at": now,
                "updated_at": now,
            }
        )
    return session_id, session_doc


@router.post("/coach/stream")
async def chat_stream(
    body: CoachRequest,
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """Server-Sent Events で chunk 単位に応答を返す."""
    _validate_input_size(body.message)
    now = datetime.now(UTC)
    session_id, session_doc = await _ensure_session(db, user_id, body, now)

    messages_ref = session_doc.collection("messages")
    history_query = messages_ref.order_by("created_at").limit(50)
    history_docs = [doc async for doc in history_query.stream()]
    history = [
        {"role": doc.get("role"), "content": doc.get("content")} for doc in history_docs
    ]

    estimate = ai_usage_service.estimate_coach_request(
        message=body.message,
        history=history,
        diary_content=body.diary_content,
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
        accumulated = ""
        try:
            async def consume():
                nonlocal accumulated
                async for chunk in coach_service.chat_stream(
                    user_message=body.message,
                    history=history,
                    diary_content=body.diary_content,
                ):
                    accumulated += chunk
                    yield chunk

            async for chunk in _with_timeout(
                consume(), settings.coach_stream_timeout_seconds
            ):
                yield f"data: {json.dumps({'chunk': chunk})}\n\n"
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
            # 完了後に assistant メッセージを保存（部分応答でも残す）
            if accumulated:
                assistant_now = datetime.now(UTC)
                assistant_msg_id = str(uuid.uuid4())
                await messages_ref.document(assistant_msg_id).set(
                    {
                        "role": "assistant",
                        "content": accumulated,
                        "metadata": {
                            "model": settings.claude_model,
                            "streamed": True,
                        },
                        "created_at": assistant_now,
                    }
                )
                snap = await session_doc.get()
                data = snap.to_dict() or {}
                await session_doc.update(
                    {
                        "message_count": data.get("message_count", 0) + 2,
                        "last_message_at": assistant_now,
                        "updated_at": assistant_now,
                    }
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
