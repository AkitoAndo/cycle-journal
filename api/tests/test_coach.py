"""Coach endpoint tests."""

from unittest.mock import AsyncMock, MagicMock, patch


def test_coach_requires_auth(client):
    response = client.post("/coach", json={"message": "hello"})
    assert response.status_code == 401


def test_coach_chat(auth_client, mock_firestore):
    """Test successful coach chat."""
    with patch(
        "app.routers.coach.coach_service.chat",
        new_callable=AsyncMock,
    ) as mock_chat:
        mock_chat.return_value = "そう感じたんだね。"

        # Configure mock: after set, session should report message_count
        mock_doc = mock_firestore._mock_doc
        snapshot_after_set = MagicMock()
        snapshot_after_set.exists = True
        snapshot_after_set.to_dict.return_value = {"message_count": 0}
        snapshot_after_set.get.return_value = "test-user-123"

        # First get: not exists. Second get: exists (after set).
        mock_doc.get = AsyncMock(
            side_effect=[mock_firestore._mock_snapshot, snapshot_after_set]
        )

        response = auth_client.post(
            "/coach",
            json={"message": "今日は疲れた"},
        )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["message"] == "そう感じたんだね。"
    assert "session_id" in data
