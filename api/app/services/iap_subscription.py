"""IAP サブスクリプション状態の組み立て (B1 verify / B2 ASSN webhook 共通).

App Store の `JWSTransactionDecodedPayload` と ASSN の通知種別から、Firestore の
`users/{uid}/subscription/{originalTransactionId}` に保存する状態レコードを構築する
純関数を提供する。Firestore I/O は呼び出し側 (router) が担い、本モジュールは
ライブラリ型と通知種別のみに依存させてユニットテスト可能にする。
"""

from __future__ import annotations

from typing import Any


def normalize_enum(value: Any) -> str | None:
    """ライブラリの Enum (例 NotificationTypeV2.SUBSCRIBED) でも、テストで渡される
    生文字列でも、一貫して "SUBSCRIBED" のような素の名前に正規化する。"""
    if value is None:
        return None
    # str Enum は .value を持つ
    inner = getattr(value, "value", None)
    if isinstance(inner, str):
        return inner
    return str(value)


def resolve_is_active(
    *,
    expires_date_ms: int | None,
    revocation_date_ms: int | None,
    now_ms: int,
) -> bool:
    """エンタイトルメントが有効かを判定する (権威的なシグナル).

    返金/失効 (revocationDate あり) は無効。期限なし (買い切り等) は有効。
    それ以外は expiresDate が現在時刻より未来なら有効。
    """
    if revocation_date_ms is not None:
        return False
    if expires_date_ms is None:
        return True
    return expires_date_ms > now_ms


def resolve_status(
    *,
    is_active: bool,
    notification_type: str | None,
    subtype: str | None,
    revocation_date_ms: int | None,
    offer_type: Any | None,
) -> str:
    """ユーザー向けのサブスク状態ラベルを導出する.

    isActive (権威判定) を補完する人間可読ステータス。
    """
    nt = normalize_enum(notification_type)
    st = normalize_enum(subtype)

    if revocation_date_ms is not None or nt in {"REFUND", "REVOKE"}:
        return "revoked"
    if not is_active:
        return "expired"
    if nt == "DID_FAIL_TO_RENEW":
        # GRACE_PERIOD 中はアクセス維持、それ以外は請求リトライ
        return "grace_period" if st == "GRACE_PERIOD" else "billing_retry"
    if nt == "DID_CHANGE_RENEWAL_STATUS" and st == "AUTO_RENEW_DISABLED":
        # 解約予約済みだが期限までは有効
        return "cancelled"
    # offerType=1 (INTRODUCTORY) は本アプリでは 7 日無料トライアルのみ
    if normalize_enum(offer_type) in {"1", "INTRODUCTORY", "OfferType.INTRODUCTORY"}:
        return "trial"
    return "active"


def build_subscription_record(
    txn: Any,
    *,
    now_ms: int,
    notification_type: Any | None = None,
    subtype: Any | None = None,
) -> dict[str, Any]:
    """検証済みトランザクションから subscription レコード (dict) を構築する.

    `updated_at` などの Firestore センチネルは含めない (呼び出し側で付与)。
    """
    expires = txn.expiresDate
    revocation = txn.revocationDate
    is_active = resolve_is_active(
        expires_date_ms=expires,
        revocation_date_ms=revocation,
        now_ms=now_ms,
    )
    status = resolve_status(
        is_active=is_active,
        notification_type=notification_type,
        subtype=subtype,
        revocation_date_ms=revocation,
        offer_type=getattr(txn, "offerType", None),
    )

    auto_renew: bool | None = None
    st = normalize_enum(subtype)
    if st == "AUTO_RENEW_DISABLED":
        auto_renew = False
    elif st == "AUTO_RENEW_ENABLED":
        auto_renew = True

    return {
        "product_id": txn.productId,
        "original_transaction_id": txn.originalTransactionId,
        "transaction_id": txn.transactionId,
        "is_active": is_active,
        "status": status,
        "expires_date_ms": expires,
        "purchase_date_ms": txn.purchaseDate,
        "revocation_date_ms": revocation,
        "environment": normalize_enum(getattr(txn, "environment", None)),
        "auto_renew": auto_renew,
        "last_notification_type": normalize_enum(notification_type),
        "last_subtype": st,
    }
