"""Test fixtures."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient


def _make_mock_firestore():
    """Create a MagicMock that acts like Firestore AsyncClient.

    All methods that get awaited in the code must return AsyncMock.
    """
    db = MagicMock()

    # Default: collection().document().get() returns a snapshot with exists=False
    mock_snapshot = MagicMock()
    mock_snapshot.exists = False
    mock_snapshot.to_dict.return_value = {}

    mock_doc = MagicMock()
    mock_doc.get = AsyncMock(return_value=mock_snapshot)
    mock_doc.set = AsyncMock()
    mock_doc.update = AsyncMock()
    mock_doc.delete = AsyncMock()

    # Subcollection support
    mock_subcollection = MagicMock()
    mock_sub_doc = MagicMock()
    mock_sub_doc.set = AsyncMock()
    mock_sub_doc.delete = AsyncMock()
    mock_subcollection.document.return_value = mock_sub_doc

    async def empty_stream():
        return
        yield  # noqa: unreachable - makes this an async generator

    mock_sub_query = MagicMock()
    mock_sub_query.stream.return_value = empty_stream()
    mock_sub_query.limit.return_value = mock_sub_query
    mock_subcollection.order_by.return_value = mock_sub_query
    mock_subcollection.stream.return_value = empty_stream()

    mock_doc.collection.return_value = mock_subcollection

    mock_collection = MagicMock()
    mock_collection.document.return_value = mock_doc

    db.collection.return_value = mock_collection
    db._mock_doc = mock_doc
    db._mock_snapshot = mock_snapshot
    db._mock_subcollection = mock_subcollection

    return db


@pytest.fixture
def mock_firestore():
    """Mock Firestore client."""
    return _make_mock_firestore()


@pytest.fixture
def mock_auth():
    """Mock Apple auth to return a fixed user_id."""
    with patch(
        "app.middleware.auth_middleware.verify_apple_token",
        new_callable=AsyncMock,
    ) as mock:
        mock.return_value = {"sub": "test-user-123", "email": "test@example.com"}
        yield mock


@pytest.fixture
def client(mock_firestore):
    """FastAPI test client with dependency overrides."""
    from app.dependencies import get_firestore
    from app.main import app

    app.dependency_overrides[get_firestore] = lambda: mock_firestore
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture
def auth_client(mock_firestore, mock_auth):
    """FastAPI test client with mocked auth and Firestore."""
    from app.dependencies import get_current_user, get_firestore
    from app.main import app

    app.dependency_overrides[get_firestore] = lambda: mock_firestore
    app.dependency_overrides[get_current_user] = lambda: "test-user-123"
    yield TestClient(app)
    app.dependency_overrides.clear()
