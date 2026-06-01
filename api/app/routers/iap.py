"""Apple In-App Purchase webhook & verify endpoints.

- POST /iap/apple/notifications  — App Store Server Notifications V2 受信口
- POST /iap/apple/verify         — クライアント (StoreKit2) からの JWS 即時検証

Notification 処理ポリシー:
- notificationUUID をドキュメント ID として iap_notifications コレクションに
  create() を試み、AlreadyExists なら冪等にスキップして 200 を返す。
- 検証失敗 (JWS) は 400 を返し Apple のリトライ対象から外す。
- 状態反映 (users/{uid}/subscription) はバックグラウンドタスクで実行し、
  Apple への ACK は即時 200 を返す (3〜5 秒以内の応答要件を満たすため)。

ユーザー特定:
- iOS は購入後 jwsRepresentation を POST /iap/apple/verify に送る。verify は
  認証済みなので uid が分かり、originalTransactionId → uid を iap_links に記録する。
- webhook は originalTransactionId から iap_links を引いて uid を解決する。
"""

from __future__ import annotations

import time
from typing import Any

from appstoreserverlibrary.signed_data_verifier import (
    SignedDataVerifier,
    VerificationException,
)
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request
from google.api_core.exceptions import AlreadyExists
from google.cloud.firestore import SERVER_TIMESTAMP, AsyncClient
from pydantic import BaseModel, Field

from app.dependencies import get_current_user, get_firestore
from app.services.iap_subscription import build_subscription_record
from app.services.iap_verifier import get_verifier

router = APIRouter(prefix="/iap", tags=["iap"])


def _now_ms() -> int:
    return int(time.time() * 1000)


async def _write_subscription_record(
    db: AsyncClient,
    uid: str,
    record: dict[str, Any],
) -> None:
    """users/{uid}/subscription/{originalTransactionId} を upsert する."""
    original_tx_id = record["original_transaction_id"]
    doc = (
        db.collection("users")
        .document(uid)
        .collection("subscription")
        .document(original_tx_id)
    )
    await doc.set({**record, "updated_at": SERVER_TIMESTAMP}, merge=True)


async def _resolve_uid(db: AsyncClient, original_tx_id: str | None) -> str | None:
    """originalTransactionId から uid を解決する (verify が記録した iap_links 経由)."""
    if not original_tx_id:
        return None
    snap = await db.collection("iap_links").document(original_tx_id).get()
    if snap.exists:
        return (snap.to_dict() or {}).get("uid")
    return None


@router.post("/apple/notifications", status_code=200)
async def apple_notifications(
    request: Request,
    background_tasks: BackgroundTasks,
    verifier: SignedDataVerifier = Depends(get_verifier),
    db: AsyncClient = Depends(get_firestore),
) -> dict[str, Any]:
    """App Store Server Notifications V2 受信口."""
    body = await request.json()
    signed = body.get("signedPayload")
    if not signed:
        raise HTTPException(status_code=400, detail="missing signedPayload")

    try:
        payload = verifier.verify_and_decode_notification(signed)
    except VerificationException as exc:
        raise HTTPException(status_code=400, detail=f"invalid signature: {exc}") from exc  # noqa: E501

    notification_uuid = payload.notificationUUID
    notif_doc = db.collection("iap_notifications").document(notification_uuid)
    try:
        await notif_doc.create(
            {
                "notificationType": str(payload.notificationType),
                "subtype": str(payload.subtype) if payload.subtype else None,
                "signedDate": payload.signedDate,
                "environment": str(payload.data.environment) if payload.data else None,
                "received_at": SERVER_TIMESTAMP,
            }
        )
    except AlreadyExists:
        return {"status": "duplicate", "notificationUUID": notification_uuid}

    background_tasks.add_task(_apply_notification, db, verifier, payload)

    return {"status": "accepted", "notificationUUID": notification_uuid}


async def _apply_notification(
    db: AsyncClient,
    verifier: SignedDataVerifier,
    payload: Any,
) -> None:
    """signedTransactionInfo をデコードして users/{uid}/subscription に状態反映する.

    - TEST 通知やトランザクションを伴わない通知は何もしない。
    - uid が未解決 (verify 未実行) の場合はスキップ。次回の verify で整合する。
    - バックグラウンド実行のため例外は握り潰す (Apple への ACK は既に返済み)。
    """
    try:
        data = getattr(payload, "data", None)
        signed_tx = getattr(data, "signedTransactionInfo", None) if data else None
        if not signed_tx:
            return

        txn = verifier.verify_and_decode_signed_transaction(signed_tx)
        uid = await _resolve_uid(db, txn.originalTransactionId)
        if uid is None:
            return

        record = build_subscription_record(
            txn,
            now_ms=_now_ms(),
            notification_type=payload.notificationType,
            subtype=payload.subtype,
        )
        await _write_subscription_record(db, uid, record)
    except Exception:  # noqa: BLE001 - background task, never raise to caller
        return


class VerifyRequest(BaseModel):
    """StoreKit2 の Transaction.jwsRepresentation を渡す."""

    jws_representation: str = Field(alias="jwsRepresentation")

    model_config = {"populate_by_name": True}


@router.post("/apple/verify", status_code=200)
async def apple_verify(
    req: VerifyRequest,
    uid: str = Depends(get_current_user),
    verifier: SignedDataVerifier = Depends(get_verifier),
    db: AsyncClient = Depends(get_firestore),
) -> dict[str, Any]:
    """クライアント (StoreKit2) からの JWS 即時検証.

    - jwsRepresentation を検証・デコード。
    - originalTransactionId → uid を iap_links に記録 (webhook がこれで uid 解決)。
    - users/{uid}/subscription にエンタイトルメントを反映し、状態を返す。
    """
    try:
        txn = verifier.verify_and_decode_signed_transaction(req.jws_representation)
    except VerificationException as exc:
        raise HTTPException(status_code=400, detail=f"invalid signature: {exc}") from exc  # noqa: E501

    original_tx_id = txn.originalTransactionId
    if not original_tx_id:
        raise HTTPException(status_code=400, detail="missing originalTransactionId")

    await db.collection("iap_links").document(original_tx_id).set(
        {"uid": uid, "updated_at": SERVER_TIMESTAMP},
        merge=True,
    )

    record = build_subscription_record(txn, now_ms=_now_ms())
    await _write_subscription_record(db, uid, record)

    return {
        "status": "verified",
        "isActive": record["is_active"],
        "subscriptionStatus": record["status"],
        "productId": record["product_id"],
        "expiresDateMs": record["expires_date_ms"],
    }
