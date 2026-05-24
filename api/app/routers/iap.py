"""Apple In-App Purchase webhook & verify endpoints.

- POST /iap/apple/notifications  — App Store Server Notifications V2 受信口
- POST /iap/apple/verify         — クライアント (StoreKit2) からの JWS 即時検証

Notification 処理ポリシー:
- notificationUUID をドキュメント ID として iap_notifications コレクションに
  create() を試み、AlreadyExists なら冪等にスキップして 200 を返す。
- 検証失敗 (JWS) は 400 を返し Apple のリトライ対象から外す。
- 状態反映 (users/{uid}/subscription) はバックグラウンドタスクで実行し、
  Apple への ACK は即時 200 を返す (3〜5 秒以内の応答要件を満たすため)。
"""

from __future__ import annotations

from typing import Any

from appstoreserverlibrary.signed_data_verifier import (
    SignedDataVerifier,
    VerificationException,
)
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request
from google.api_core.exceptions import AlreadyExists
from google.cloud.firestore import SERVER_TIMESTAMP, AsyncClient

from app.dependencies import get_firestore
from app.services.iap_verifier import get_verifier

router = APIRouter(prefix="/iap", tags=["iap"])


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

    # TODO(#37): バックグラウンドで users/{uid}/subscription を更新する
    # (signedTransactionInfo / signedRenewalInfo をデコードして state machine 反映)
    background_tasks.add_task(_noop_apply_notification, payload)

    return {"status": "accepted", "notificationUUID": notification_uuid}


async def _noop_apply_notification(payload: Any) -> None:
    """状態反映ロジックの placeholder.

    後続 PR で signedTransactionInfo / signedRenewalInfo をデコードし
    users/{uid}/subscription を更新する処理に差し替える。
    """
    return None
