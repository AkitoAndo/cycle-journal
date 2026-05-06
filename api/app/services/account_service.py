"""Account deletion service.

ユーザーアカウントを完全に削除する。Apple Sign in 連携時は Apple 側で
refresh token を revoke し、その後 Firestore のユーザー関連データを全消去する。

App Store Review Guideline 5.1.1(v) 準拠。
"""

import logging

from google.cloud.firestore import AsyncClient
from google.cloud.firestore_v1.base_query import FieldFilter

from app.services.apple_auth import revoke_apple_refresh_token
from app.services.firestore_client import (
    refresh_tokens_ref,
    sessions_ref,
    tasks_ref,
    users_ref,
)

logger = logging.getLogger(__name__)


async def delete_user_account(db: AsyncClient, user_id: str) -> dict[str, int | bool]:
    """ユーザーに紐づく全データを削除する.

    Returns: 削除統計 dict（呼び出し元でログ・監視しやすいように）
        - apple_revoked: Apple 側で revoke できたか (True/False)
        - sessions_deleted: 削除したセッション数
        - tasks_deleted: 削除したタスク数
        - refresh_tokens_deleted: 削除した server-issued refresh token 数
        - user_doc_deleted: ユーザードキュメント削除可否 (True/False)
    """
    user_doc_ref = users_ref(db).document(user_id)
    snapshot = await user_doc_ref.get()

    apple_revoked = False
    if snapshot.exists:
        data = snapshot.to_dict() or {}
        apple_token = data.get("apple_refresh_token")
        if apple_token:
            apple_revoked = await revoke_apple_refresh_token(apple_token)

    sessions_deleted = await _delete_owned_documents(
        db,
        sessions_ref(db),
        user_id=user_id,
        subcollections=("messages",),
    )
    tasks_deleted = await _delete_owned_documents(
        db,
        tasks_ref(db),
        user_id=user_id,
        subcollections=("reflections",),
    )
    refresh_deleted = await _delete_user_refresh_tokens(db, user_id)

    user_doc_deleted = False
    if snapshot.exists:
        await user_doc_ref.delete()
        user_doc_deleted = True

    logger.info(
        "Deleted account user_id=%s apple_revoked=%s sessions=%d tasks=%d "
        "refresh_tokens=%d user_doc=%s",
        user_id,
        apple_revoked,
        sessions_deleted,
        tasks_deleted,
        refresh_deleted,
        user_doc_deleted,
    )

    return {
        "apple_revoked": apple_revoked,
        "sessions_deleted": sessions_deleted,
        "tasks_deleted": tasks_deleted,
        "refresh_tokens_deleted": refresh_deleted,
        "user_doc_deleted": user_doc_deleted,
    }


async def _delete_owned_documents(
    db: AsyncClient,
    collection,
    *,
    user_id: str,
    subcollections: tuple[str, ...] = (),
) -> int:
    """`user_id` フィールドが一致するドキュメントとそのサブコレクションを全削除する."""
    query = collection.where(filter=FieldFilter("user_id", "==", user_id))
    deleted = 0
    async for doc in query.stream():
        for sub_name in subcollections:
            await _delete_subcollection(doc.reference.collection(sub_name))
        await doc.reference.delete()
        deleted += 1
    return deleted


async def _delete_subcollection(sub_collection) -> None:
    async for sub_doc in sub_collection.stream():
        await sub_doc.reference.delete()


async def _delete_user_refresh_tokens(db: AsyncClient, user_id: str) -> int:
    query = refresh_tokens_ref(db).where(
        filter=FieldFilter("user_id", "==", user_id)
    )
    deleted = 0
    async for doc in query.stream():
        await doc.reference.delete()
        deleted += 1
    return deleted
