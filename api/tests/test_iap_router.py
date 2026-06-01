"""IAP webhook + verify router tests (A backend).

App Store Server Notifications V2 を受け、JWS 検証 + 冪等性担保 +
Firestore subscription 状態更新を行うエンドポイントの結合テスト。

library 本体 (SignedDataVerifier) はモック化、Firestore も既存 conftest
の mock を流用する。
"""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient


def _make_decoded_payload(
    notification_type: str = "SUBSCRIBED",
    notification_uuid: str = "uuid-1",
    environment: str = "Sandbox",
):
    """ResponseBodyV2DecodedPayload 風のモックを返す."""
    payload = MagicMock()
    payload.notificationType = notification_type
    payload.subtype = None
    payload.notificationUUID = notification_uuid
    payload.signedDate = 1700000000000
    data = MagicMock()
    data.environment = environment
    data.signedTransactionInfo = "signed-transaction-jws"
    data.signedRenewalInfo = "signed-renewal-jws"
    payload.data = data
    return payload


@pytest.fixture
def iap_client(mock_firestore):
    """Firestore と SignedDataVerifier を依存性注入で差し替えたクライアント."""
    from app.dependencies import get_firestore
    from app.main import app
    from app.services.iap_verifier import get_verifier

    verifier = MagicMock()
    app.dependency_overrides[get_firestore] = lambda: mock_firestore
    app.dependency_overrides[get_verifier] = lambda: verifier
    yield TestClient(app), verifier
    app.dependency_overrides.clear()


def test_apple_notifications_rejects_missing_signed_payload(iap_client):
    """A: signedPayload キーがないと 400."""
    client, _ = iap_client
    response = client.post("/iap/apple/notifications", json={})
    assert response.status_code == 400


def test_apple_notifications_rejects_invalid_signature(iap_client):
    """A: JWS 検証失敗時は 400."""
    from appstoreserverlibrary.signed_data_verifier import (
        VerificationException,
        VerificationStatus,
    )

    client, verifier = iap_client
    verifier.verify_and_decode_notification.side_effect = VerificationException(
        VerificationStatus.INVALID_CERTIFICATE
    )

    response = client.post(
        "/iap/apple/notifications",
        json={"signedPayload": "invalid-jws"},
    )

    assert response.status_code == 400


def test_apple_notifications_accepts_valid_payload(iap_client, mock_firestore):
    """A: 正常な signedPayload で 200 を返し notificationUUID を Firestore に記録."""
    client, verifier = iap_client
    verifier.verify_and_decode_notification.return_value = _make_decoded_payload(
        notification_uuid="uuid-accept"
    )

    response = client.post(
        "/iap/apple/notifications",
        json={"signedPayload": "valid-jws"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "accepted"
    assert body["notificationUUID"] == "uuid-accept"
    mock_firestore.collection.assert_any_call("iap_notifications")


def test_apple_notifications_is_idempotent(iap_client, mock_firestore):
    """A: 同一 notificationUUID の重複受信は 200 ("duplicate") で返す."""
    from google.api_core.exceptions import AlreadyExists

    client, verifier = iap_client
    verifier.verify_and_decode_notification.return_value = _make_decoded_payload(
        notification_uuid="uuid-duplicate"
    )
    mock_firestore._mock_doc.create = AsyncMock(
        side_effect=AlreadyExists("already exists")
    )

    response = client.post(
        "/iap/apple/notifications",
        json={"signedPayload": "valid-jws"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body.get("status") == "duplicate"


# ---------------------------------------------------------------------------
# B1: POST /iap/apple/verify
# ---------------------------------------------------------------------------

# endpoint は実時刻 (time.time()) を使うため、実 now より十分未来の固定値を使う
NOW_MS = 1_700_000_000_000
FUTURE_MS = 4_102_444_800_000  # 2100-01-01 頃


def _make_txn(
    original_tx_id: str | None = "2000000000000001",
    expires: int | None = FUTURE_MS,
    revocation: int | None = None,
):
    """JWSTransactionDecodedPayload 風のモック."""
    return SimpleNamespace(
        productId="com.akitoando.CycleJournal.yearly_14400",
        originalTransactionId=original_tx_id,
        transactionId="2000000000000002",
        expiresDate=expires,
        purchaseDate=NOW_MS - 1000,
        revocationDate=revocation,
        environment="Sandbox",
        offerType=None,
    )


@pytest.fixture
def iap_auth_client(mock_firestore):
    """get_current_user も差し替えた認証済みクライアント."""
    from app.dependencies import get_current_user, get_firestore
    from app.main import app
    from app.services.iap_verifier import get_verifier

    verifier = MagicMock()
    app.dependency_overrides[get_firestore] = lambda: mock_firestore
    app.dependency_overrides[get_verifier] = lambda: verifier
    app.dependency_overrides[get_current_user] = lambda: "user-abc"
    yield TestClient(app), verifier, mock_firestore
    app.dependency_overrides.clear()


def test_verify_records_link_and_subscription(iap_auth_client):
    """B1: 正常な jws で 200・iap_links と users/{uid}/subscription を書き込む."""
    client, verifier, mock_firestore = iap_auth_client
    verifier.verify_and_decode_signed_transaction.return_value = _make_txn()

    response = client.post(
        "/iap/apple/verify",
        json={"jwsRepresentation": "valid-jws"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "verified"
    assert body["isActive"] is True
    assert body["subscriptionStatus"] == "active"
    mock_firestore.collection.assert_any_call("iap_links")
    mock_firestore.collection.assert_any_call("users")


def test_verify_rejects_invalid_signature(iap_auth_client):
    """B1: JWS 検証失敗は 400."""
    from appstoreserverlibrary.signed_data_verifier import (
        VerificationException,
        VerificationStatus,
    )

    client, verifier, _ = iap_auth_client
    verifier.verify_and_decode_signed_transaction.side_effect = VerificationException(
        VerificationStatus.INVALID_CERTIFICATE
    )

    response = client.post(
        "/iap/apple/verify",
        json={"jwsRepresentation": "bad-jws"},
    )
    assert response.status_code == 400


def test_verify_rejects_missing_original_transaction_id(iap_auth_client):
    """B1: originalTransactionId が無い場合は 400."""
    client, verifier, _ = iap_auth_client
    verifier.verify_and_decode_signed_transaction.return_value = _make_txn(
        original_tx_id=None
    )

    response = client.post(
        "/iap/apple/verify",
        json={"jwsRepresentation": "jws-no-otid"},
    )
    assert response.status_code == 400


def test_notification_applies_when_uid_resolved(iap_client, mock_firestore):
    """B2: iap_links に uid があれば webhook が subscription を更新する."""
    client, verifier = iap_client
    verifier.verify_and_decode_notification.return_value = _make_decoded_payload(
        notification_type="DID_RENEW", notification_uuid="uuid-apply"
    )
    verifier.verify_and_decode_signed_transaction.return_value = _make_txn()
    mock_firestore._mock_snapshot.exists = True
    mock_firestore._mock_snapshot.to_dict.return_value = {"uid": "user-xyz"}

    response = client.post(
        "/iap/apple/notifications",
        json={"signedPayload": "valid-jws"},
    )

    assert response.status_code == 200
    mock_firestore.collection.assert_any_call("users")
