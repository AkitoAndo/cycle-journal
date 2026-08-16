"""Task endpoint tests."""

import uuid
from datetime import UTC, datetime
from unittest.mock import MagicMock


def test_list_tasks_requires_auth(client):
    response = client.get("/tasks")
    assert response.status_code == 401


def test_create_task_requires_auth(client):
    response = client.post("/tasks", json={"title": "Test"})
    assert response.status_code == 401


def test_create_task_uses_user_scoped_idempotency_key(auth_client, mock_firestore):
    client_task_id = "550e8400-e29b-41d4-a716-446655440000"

    response = auth_client.post(
        "/tasks",
        json={"title": "同期されるタスク", "client_task_id": client_task_id},
    )

    assert response.status_code == 201
    expected_id = str(
        uuid.uuid5(
            uuid.NAMESPACE_URL,
            f"cycle:test-user-123:{client_task_id}",
        )
    )
    assert response.json()["data"]["task_id"] == expected_id
    mock_firestore.collection.return_value.document.assert_called_with(expected_id)
    saved = mock_firestore._mock_doc.set.await_args.args[0]
    assert saved["client_task_id"] == client_task_id


def test_reopening_task_clears_completed_at(auth_client, mock_firestore):
    now = datetime.now(UTC)
    existing = MagicMock()
    existing.exists = True
    existing.to_dict.return_value = {
        "user_id": "test-user-123",
        "title": "完了済み",
        "status": "completed",
        "completed_at": now,
        "created_at": now,
        "updated_at": now,
    }
    updated = MagicMock()
    updated.to_dict.return_value = {
        "user_id": "test-user-123",
        "title": "完了済み",
        "status": "pending",
        "completed_at": None,
        "created_at": now,
        "updated_at": now,
    }
    mock_firestore._mock_doc.get.side_effect = [existing, updated]

    response = auth_client.put("/tasks/task-1", json={"status": "pending"})

    assert response.status_code == 200
    updates = mock_firestore._mock_doc.update.await_args.args[0]
    assert updates["status"] == "pending"
    assert updates["completed_at"] is None
