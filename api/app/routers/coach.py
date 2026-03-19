"""Coach endpoint - AI coaching with Vertex AI Claude."""

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends
from google.cloud.firestore import AsyncClient

from app.config import settings
from app.dependencies import get_current_user, get_firestore
from app.models.coach import CoachData, CoachMetadata, CoachRequest
from app.services import coach_service
from app.services.firestore_client import sessions_ref

router = APIRouter(tags=["Coach"])


@router.post("/coach")
async def chat(
    body: CoachRequest,
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """ユーザーのメッセージに対してAIコーチが応答."""
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
        cycle_element = body.context.cycle_element.value if body.context and body.context.cycle_element else None
        await session_doc.set({
            "user_id": user_id,
            "title": None,
            "cycle_element": cycle_element,
            "has_diary_context": body.diary_content is not None,
            "message_count": 0,
            "last_message_at": now,
            "created_at": now,
            "updated_at": now,
        })

    # 過去のメッセージ履歴を取得
    messages_ref = session_doc.collection("messages")
    history_query = messages_ref.order_by("created_at").limit(50)
    history_docs = [doc async for doc in history_query.stream()]
    history = [
        {"role": doc.get("role"), "content": doc.get("content")}
        for doc in history_docs
    ]

    # Vertex AI Claude呼び出し
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

    return {
        "data": CoachData(
            message=response_text,
            session_id=session_id,
            metadata=CoachMetadata(
                stage=settings.environment,
                model=settings.claude_model,
                cycle_element=body.context.cycle_element if body.context else None,
            ),
        )
    }
