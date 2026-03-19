"""Session endpoints - CRUD for coaching sessions."""

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Query, Response
from google.cloud.firestore import AsyncClient

from app.dependencies import get_current_user, get_firestore
from app.exceptions import NotFoundError
from app.models.session import (
    CreateSessionRequest,
    MessageData,
    SessionDetail,
    SessionListData,
    SessionSummary,
)
from app.services.firestore_client import sessions_ref

router = APIRouter(prefix="/sessions", tags=["Sessions"])


@router.get("")
async def list_sessions(
    limit: int = Query(default=20, le=100),
    offset: int = Query(default=0, ge=0),
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """ユーザーの会話セッション一覧を取得."""
    ref = sessions_ref(db)
    query = (
        ref.where("user_id", "==", user_id)
        .order_by("created_at", direction="DESCENDING")
    )

    # 全件数を取得
    all_docs = [doc async for doc in query.stream()]
    total = len(all_docs)

    # ページネーション適用
    paginated = all_docs[offset : offset + limit]

    sessions = []
    for doc in paginated:
        data = doc.to_dict() or {}
        sessions.append(
            SessionSummary(
                session_id=doc.id,
                title=data.get("title"),
                cycle_element=data.get("cycle_element"),
                message_count=data.get("message_count", 0),
                last_message_at=data.get("last_message_at"),
                created_at=data.get("created_at"),
            )
        )

    return {
        "data": SessionListData(
            sessions=sessions,
            total=total,
            limit=limit,
            offset=offset,
        )
    }


@router.post("", status_code=201)
async def create_session(
    body: CreateSessionRequest,
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """新しい会話セッションを作成."""
    ref = sessions_ref(db)
    session_id = str(uuid.uuid4())
    now = datetime.now(UTC)

    session_data = {
        "user_id": user_id,
        "title": body.title,
        "cycle_element": body.cycle_element.value if body.cycle_element else None,
        "has_diary_context": body.diary_content is not None,
        "message_count": 0,
        "last_message_at": now,
        "created_at": now,
        "updated_at": now,
    }
    await ref.document(session_id).set(session_data)

    return {
        "data": SessionSummary(
            session_id=session_id,
            title=body.title,
            cycle_element=body.cycle_element,
            message_count=0,
            last_message_at=now,
            created_at=now,
        )
    }


@router.get("/{session_id}")
async def get_session(
    session_id: str,
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """特定のセッションの詳細とメッセージ履歴を取得."""
    ref = sessions_ref(db)
    doc = ref.document(session_id)
    snapshot = await doc.get()

    if not snapshot.exists:
        raise NotFoundError("Session")

    data = snapshot.to_dict() or {}
    if data.get("user_id") != user_id:
        raise NotFoundError("Session")

    # メッセージ取得
    messages_ref = doc.collection("messages")
    msg_query = messages_ref.order_by("created_at")
    messages = []
    async for msg_doc in msg_query.stream():
        msg_data = msg_doc.to_dict() or {}
        messages.append(
            MessageData(
                message_id=msg_doc.id,
                role=msg_data.get("role", ""),
                content=msg_data.get("content", ""),
                metadata=msg_data.get("metadata"),
                created_at=msg_data.get("created_at"),
            )
        )

    return {
        "data": SessionDetail(
            session_id=session_id,
            title=data.get("title"),
            cycle_element=data.get("cycle_element"),
            has_diary_context=data.get("has_diary_context", False),
            messages=messages,
            created_at=data.get("created_at"),
            updated_at=data.get("updated_at"),
        )
    }


@router.delete("/{session_id}", status_code=204)
async def delete_session(
    session_id: str,
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """セッションを削除."""
    ref = sessions_ref(db)
    doc = ref.document(session_id)
    snapshot = await doc.get()

    if not snapshot.exists:
        raise NotFoundError("Session")

    data = snapshot.to_dict() or {}
    if data.get("user_id") != user_id:
        raise NotFoundError("Session")

    # サブコレクション（messages）も削除
    messages_ref = doc.collection("messages")
    async for msg_doc in messages_ref.stream():
        await msg_doc.reference.delete()

    await doc.delete()
    return Response(status_code=204)
