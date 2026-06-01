"""build_subscription_record / 状態導出ロジックのユニットテスト (B1/B2 共通)."""

from __future__ import annotations

from types import SimpleNamespace

from app.services.iap_subscription import (
    build_subscription_record,
    normalize_enum,
    resolve_is_active,
)

NOW = 1_700_000_000_000  # 固定の現在時刻 (ms)
FUTURE = NOW + 7 * 24 * 60 * 60 * 1000
PAST = NOW - 1000


def _txn(**overrides):
    base = dict(
        productId="com.akitoando.CycleJournal.yearly_14400",
        originalTransactionId="2000000000000001",
        transactionId="2000000000000002",
        expiresDate=FUTURE,
        purchaseDate=NOW - 1000,
        revocationDate=None,
        environment="Sandbox",
        offerType=None,
    )
    base.update(overrides)
    return SimpleNamespace(**base)


def test_normalize_enum_handles_enum_and_str():
    assert normalize_enum("SUBSCRIBED") == "SUBSCRIBED"
    assert normalize_enum(SimpleNamespace(value="DID_RENEW")) == "DID_RENEW"
    assert normalize_enum(None) is None


def test_resolve_is_active_rules():
    assert resolve_is_active(
        expires_date_ms=FUTURE, revocation_date_ms=None, now_ms=NOW
    )
    assert not resolve_is_active(
        expires_date_ms=PAST, revocation_date_ms=None, now_ms=NOW
    )
    # 返金/失効は期限が未来でも無効
    assert not resolve_is_active(
        expires_date_ms=FUTURE, revocation_date_ms=NOW, now_ms=NOW
    )
    # 期限なし (買い切り) は有効
    assert resolve_is_active(
        expires_date_ms=None, revocation_date_ms=None, now_ms=NOW
    )


def test_active_subscription():
    rec = build_subscription_record(_txn(), now_ms=NOW, notification_type="DID_RENEW")
    assert rec["is_active"] is True
    assert rec["status"] == "active"
    assert rec["product_id"].endswith("yearly_14400")
    assert rec["original_transaction_id"] == "2000000000000001"


def test_trial_subscription_from_offer_type():
    rec = build_subscription_record(
        _txn(offerType="INTRODUCTORY"), now_ms=NOW, notification_type="SUBSCRIBED"
    )
    assert rec["is_active"] is True
    assert rec["status"] == "trial"


def test_expired_subscription():
    rec = build_subscription_record(
        _txn(expiresDate=PAST), now_ms=NOW, notification_type="EXPIRED"
    )
    assert rec["is_active"] is False
    assert rec["status"] == "expired"


def test_revoked_subscription():
    rec = build_subscription_record(
        _txn(revocationDate=NOW), now_ms=NOW, notification_type="REFUND"
    )
    assert rec["is_active"] is False
    assert rec["status"] == "revoked"


def test_cancelled_but_still_active():
    """解約予約 (AUTO_RENEW_DISABLED) でも期限までは有効・status=cancelled."""
    rec = build_subscription_record(
        _txn(),
        now_ms=NOW,
        notification_type="DID_CHANGE_RENEWAL_STATUS",
        subtype="AUTO_RENEW_DISABLED",
    )
    assert rec["is_active"] is True
    assert rec["status"] == "cancelled"
    assert rec["auto_renew"] is False


def test_grace_period_keeps_access():
    rec = build_subscription_record(
        _txn(),
        now_ms=NOW,
        notification_type="DID_FAIL_TO_RENEW",
        subtype="GRACE_PERIOD",
    )
    assert rec["is_active"] is True
    assert rec["status"] == "grace_period"
