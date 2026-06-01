"""Firestore client tests."""

from unittest.mock import patch

from app.services import firestore_client


def test_get_db_uses_configured_database_id():
    """Firestore AsyncClient に database_id を渡して環境ごとの DB を使う."""
    firestore_client._db = None
    try:
        with (
            patch.object(
                firestore_client.settings,
                "gcp_project_id",
                "cycle-journal-test",
            ),
            patch.object(firestore_client.settings, "firestore_database_id", "dev"),
            patch.object(firestore_client, "AsyncClient") as async_client,
        ):
            db = firestore_client.get_db()

        assert db == async_client.return_value
        async_client.assert_called_once_with(
            project="cycle-journal-test",
            database="dev",
        )
    finally:
        firestore_client._db = None
