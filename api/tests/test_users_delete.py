"""DELETE /users/me エンドポイントのテスト."""

from unittest.mock import AsyncMock, patch


def test_delete_me_revokes_apple_token_when_present(auth_client, mock_firestore):
    """apple_refresh_token があれば Apple revoke を呼んで全データ削除する."""
    mock_firestore._mock_snapshot.exists = True
    mock_firestore._mock_snapshot.to_dict.return_value = {
        "apple_refresh_token": "apple-refresh-abc",
    }

    with patch(
        "app.services.account_service.revoke_apple_refresh_token",
        new_callable=AsyncMock,
    ) as mock_revoke:
        mock_revoke.return_value = True

        response = auth_client.delete("/users/me")

    assert response.status_code == 200
    body = response.json()["data"]
    assert body["ok"] is True
    assert body["apple_revoked"] is True
    assert body["user_doc_deleted"] is True
    assert body["journals_deleted"] == 0
    assert body["ai_usage_records_deleted"] == 0
    assert body["iap_links_deleted"] == 0
    assert body["user_subcollection_documents_deleted"] == 0
    mock_revoke.assert_awaited_once_with("apple-refresh-abc")
    mock_firestore._mock_doc.delete.assert_awaited()
    requested_collections = {
        call.args[0] for call in mock_firestore.collection.call_args_list
    }
    assert {
        "users",
        "sessions",
        "tasks",
        "journals",
        "refresh_tokens",
        "ai_usage_monthly",
        "iap_links",
    }.issubset(requested_collections)


def test_delete_me_skips_revoke_when_no_apple_token(auth_client, mock_firestore):
    """apple_refresh_token が無い場合は Apple revoke を呼ばないが削除は完了する."""
    mock_firestore._mock_snapshot.exists = True
    mock_firestore._mock_snapshot.to_dict.return_value = {}

    with patch(
        "app.services.account_service.revoke_apple_refresh_token",
        new_callable=AsyncMock,
    ) as mock_revoke:
        response = auth_client.delete("/users/me")

    assert response.status_code == 200
    body = response.json()["data"]
    assert body["ok"] is True
    assert body["apple_revoked"] is False
    assert body["user_doc_deleted"] is True
    mock_revoke.assert_not_called()


def test_delete_me_idempotent_when_user_doc_missing(auth_client, mock_firestore):
    """ユーザードキュメントが既に無くてもエンドポイントはエラーにならない."""
    mock_firestore._mock_snapshot.exists = False

    with patch(
        "app.services.account_service.revoke_apple_refresh_token",
        new_callable=AsyncMock,
    ) as mock_revoke:
        response = auth_client.delete("/users/me")

    assert response.status_code == 200
    body = response.json()["data"]
    assert body["ok"] is True
    assert body["apple_revoked"] is False
    assert body["user_doc_deleted"] is False
    mock_revoke.assert_not_called()
