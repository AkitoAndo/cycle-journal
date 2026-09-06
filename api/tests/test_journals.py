"""Journal sync endpoint tests."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient


def test_list_journals_requires_auth(client):
    response = client.get("/journals")
    assert response.status_code == 401


def test_sync_journals_requires_auth(client):
    response = client.post("/journals/sync", json={"journals": []})
    assert response.status_code == 401


def test_sync_pushes_local_journal(journal_client_factory):
    client, db = journal_client_factory()

    response = client.post(
        "/journals/sync",
        json={
            "journals": [
                {
                    "journal_id": "journal-1",
                    "text": "今日の記録",
                    "tags": ["daily"],
                    "entry_date": "2026-08-01T10:00:00Z",
                    "updated_at": "2026-08-01T10:05:00Z",
                }
            ]
        },
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["pushed_count"] == 1
    assert data["conflict_count"] == 0
    assert data["journals"][0]["journal_id"] == "journal-1"
    assert db.store["journal-1"]["user_id"] == "test-user-123"
    assert db.store["journal-1"]["text"] == "今日の記録"


def test_sync_keeps_server_journal_when_server_is_newer(journal_client_factory):
    client, db = journal_client_factory(
        {
            "journal-1": {
                "user_id": "test-user-123",
                "text": "server",
                "tags": [],
                "entry_date": _dt(2026, 8, 1, 10, 0),
                "created_at": _dt(2026, 8, 1, 10, 0),
                "updated_at": _dt(2026, 8, 2, 10, 0),
                "deleted_at": None,
            }
        }
    )

    response = client.post(
        "/journals/sync",
        json={
            "journals": [
                {
                    "journal_id": "journal-1",
                    "text": "client",
                    "tags": [],
                    "entry_date": "2026-08-01T10:00:00Z",
                    "updated_at": "2026-08-01T10:30:00Z",
                }
            ]
        },
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["pushed_count"] == 0
    assert data["conflict_count"] == 1
    assert db.store["journal-1"]["text"] == "server"
    assert data["journals"][0]["text"] == "server"


def test_sync_marks_deleted_journal_as_tombstone(journal_client_factory):
    client, db = journal_client_factory(
        {
            "journal-1": {
                "user_id": "test-user-123",
                "text": "remove me",
                "tags": ["old"],
                "entry_date": _dt(2026, 8, 1, 10, 0),
                "created_at": _dt(2026, 8, 1, 10, 0),
                "updated_at": _dt(2026, 8, 1, 10, 0),
                "deleted_at": None,
            }
        }
    )

    response = client.post(
        "/journals/sync",
        json={"journals": [], "deleted_journal_ids": ["journal-1"]},
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["deleted_count"] == 1
    assert db.store["journal-1"]["text"] == ""
    assert db.store["journal-1"]["tags"] == []
    assert db.store["journal-1"]["deleted_at"] is not None


@pytest.fixture
def journal_client_factory():
    clients: list[TestClient] = []

    def make(initial: dict[str, dict[str, Any]] | None = None):
        client, db = _client_with_store(initial or {})
        clients.append(client)
        return client, db

    yield make

    if clients:
        clients[-1].app.dependency_overrides.clear()


def _client_with_store(initial: dict[str, dict[str, Any]]):
    from app.dependencies import get_current_user, get_firestore
    from app.main import app

    db = _FakeFirestore(initial)
    app.dependency_overrides[get_firestore] = lambda: db
    app.dependency_overrides[get_current_user] = lambda: "test-user-123"
    return TestClient(app), db


def _dt(year: int, month: int, day: int, hour: int, minute: int) -> datetime:
    return datetime(year, month, day, hour, minute, tzinfo=UTC)


class _FakeFirestore:
    def __init__(self, initial: dict[str, dict[str, Any]]):
        self.store = dict(initial)

    def collection(self, name: str):
        assert name == "journals"
        return _FakeCollection(self.store)


class _FakeCollection:
    def __init__(self, store: dict[str, dict[str, Any]]):
        self.store = store

    def document(self, doc_id: str):
        return _FakeDocument(self.store, doc_id)

    def where(self, field: str, op: str, value: Any):
        return _FakeQuery(self.store, field, op, value)


class _FakeDocument:
    def __init__(self, store: dict[str, dict[str, Any]], doc_id: str):
        self.store = store
        self.id = doc_id

    async def get(self):
        return _FakeSnapshot(self.id, self.store.get(self.id))

    async def set(self, data: dict[str, Any]):
        self.store[self.id] = dict(data)

    async def update(self, data: dict[str, Any]):
        self.store[self.id].update(data)


class _FakeSnapshot:
    def __init__(self, doc_id: str, data: dict[str, Any] | None):
        self.id = doc_id
        self._data = data
        self.exists = data is not None

    def to_dict(self):
        return dict(self._data or {})


class _FakeQuery:
    def __init__(
        self,
        store: dict[str, dict[str, Any]],
        field: str,
        op: str,
        value: Any,
    ):
        self.store = store
        self.field = field
        self.op = op
        self.value = value

    async def stream(self):
        for doc_id, data in self.store.items():
            if self.op == "==" and data.get(self.field) == self.value:
                yield _FakeSnapshot(doc_id, data)
