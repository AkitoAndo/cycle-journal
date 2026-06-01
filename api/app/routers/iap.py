"""Apple In-App Purchase webhook & verify endpoints.

- POST /iap/apple/notifications  — App Store Server Notifications V2 受信口
- POST /iap/apple/verify         — クライアント (StoreKit2) からの JWS 即時検証
- POST /iap/apple/device-token   — silent push 用 APNs device token 登録

Notification 処理ポリシー:
- notificationUUID をドキュメント ID として iap_notifications コレクションに
  create() を試み、AlreadyExists なら冪等にスキップして 200 を返す。
- 検証失敗 (JWS) は 400 を返し Apple のリトライ対象から外す。
- 状態反映 (users/{uid}/subscription)・GA4・silent push はバックグラウンドで実行し、
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
from app.services.analytics_service import send_event
from app.services.apns_service import send_silent_push
from app.services.iap_events import ga4_event_name, should_send_cancel_silent_push
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


async def _get_iap_link(
    db: AsyncClient,
    original_tx_id: str | None,
) -> dict[str, Any] | None:
    """originalTransactionId から verify 時に保存したリンク情報を取得する."""
    if not original_tx_id:
        return None
    snap = await db.collection("iap_links").document(original_tx_id).get()
    if snap.exists:
        return snap.to_dict() or {}
    return None


async def _resolve_uid(db: AsyncClient, original_tx_id: str | None) -> str | None:
    """originalTransactionId から uid を解決する (verify が記録した iap_links 経由)."""
    link = await _get_iap_link(db, original_tx_id)
    return link.get("uid") if link else None


def _analytics_params(record: dict[str, Any], notification_uuid: str) -> dict[str, Any]:
    return {
        "product_id": record["product_id"],
        "subscription_status": record["status"],
        "is_active": record["is_active"],
        "transaction_id": record["transaction_id"],
        "original_transaction_id": record["original_transaction_id"],
        "expires_date_ms": record["expires_date_ms"],
        "notification_type": record["last_notification_type"],
        "notification_subtype": record["last_subtype"],
        "environment": record["environment"],
    }


async def _read_prior_status(
    db: AsyncClient,
    uid: str,
    original_tx_id: str,
) -> str | None:
    """書き込み前の subscription status を読む (Trial→Paid 転換検出用)."""
    snap = (
        await db.collection("users")
        .document(uid)
        .collection("subscription")
        .document(original_tx_id)
        .get()
    )
    if snap.exists:
        return (snap.to_dict() or {}).get("status")
    return None


async def _send_ga4_subscription_event(
    *,
    uid: str,
    link: dict[str, Any] | None,
    record: dict[str, Any],
    payload: Any,
    prior_status: str | None = None,
) -> None:
    event_name = ga4_event_name(
        payload.notificationType,
        payload.subtype,
        record["status"],
        prior_status,
    )
    if event_name is None:
        return

    client_id = (link or {}).get("ga4_client_id") or uid
    await send_event(
        client_id=client_id,
        user_id=uid,
        event_name=event_name,
        params=_analytics_params(record, payload.notificationUUID),
        event_id=payload.notificationUUID,
    )


async def _send_cancel_silent_pushes(
    *,
    db: AsyncClient,
    uid: str,
    record: dict[str, Any],
) -> None:
    token_collection = db.collection("users").document(uid).collection("apns_tokens")
    async for snap in token_collection.stream():
        token_data = snap.to_dict() or {}
        token = token_data.get("device_token")
        if not token:
            continue
        await send_silent_push(
            device_token=token,
            event="cancel_trial_notifications",
            reason="subscription_auto_renew_disabled",
            extra={
                "product_id": record["product_id"],
                "original_transaction_id": record["original_transaction_id"],
            },
        )


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
    """ASSN transaction を反映し、GA4 / silent push の後続処理を実行する.

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
        link = await _get_iap_link(db, txn.originalTransactionId)
        uid = link.get("uid") if link else None
        if uid is None:
            return

        # 書き込みで上書きする前に直前 status を読む (転換検出のため)
        prior_status = await _read_prior_status(db, uid, txn.originalTransactionId)

        record = build_subscription_record(
            txn,
            now_ms=_now_ms(),
            notification_type=payload.notificationType,
            subtype=payload.subtype,
        )
        await _write_subscription_record(db, uid, record)
        await _send_ga4_subscription_event(
            uid=uid,
            link=link,
            record=record,
            payload=payload,
            prior_status=prior_status,
        )
        if should_send_cancel_silent_push(payload.notificationType, payload.subtype):
            await _send_cancel_silent_pushes(db=db, uid=uid, record=record)
    except Exception:  # noqa: BLE001 - background task, never raise to caller
        return


class VerifyRequest(BaseModel):
    """StoreKit2 の Transaction.jwsRepresentation を渡す."""

    jws_representation: str = Field(alias="jwsRepresentation")
    ga4_client_id: str | None = Field(default=None, alias="ga4ClientId")

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

    link_record: dict[str, Any] = {"uid": uid, "updated_at": SERVER_TIMESTAMP}
    if req.ga4_client_id:
        link_record["ga4_client_id"] = req.ga4_client_id
    await db.collection("iap_links").document(original_tx_id).set(
        link_record,
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


class DeviceTokenRequest(BaseModel):
    """APNs device token registration for silent push."""

    device_token: str = Field(alias="deviceToken", min_length=16, max_length=512)
    environment: str | None = None

    model_config = {"populate_by_name": True}


@router.post("/apple/device-token", status_code=200)
async def register_device_token(
    req: DeviceTokenRequest,
    uid: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
) -> dict[str, Any]:
    """Register an APNs token used for subscription silent pushes."""
    token = req.device_token.strip().replace(" ", "").lower()
    if not token:
        raise HTTPException(status_code=400, detail="missing deviceToken")

    await (
        db.collection("users")
        .document(uid)
        .collection("apns_tokens")
        .document(token)
        .set(
            {
                "device_token": token,
                "environment": req.environment,
                "updated_at": SERVER_TIMESTAMP,
            },
            merge=True,
        )
    )
    return {"status": "registered"}
