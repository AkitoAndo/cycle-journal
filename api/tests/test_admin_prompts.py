"""Admin prompt endpoint tests."""

from unittest.mock import AsyncMock, MagicMock, patch

from fastapi.testclient import TestClient


def _admin_db(email: str = "takeshiogata1105@gmail.com"):
    db = MagicMock()
    user_snap = MagicMock()
    user_snap.exists = True
    user_snap.get.return_value = email
    user_doc = MagicMock()
    user_doc.get = AsyncMock(return_value=user_snap)
    users = MagicMock()
    users.document.return_value = user_doc
    db.collection.return_value = users
    return db


def _client(db):
    from app.dependencies import get_firestore
    from app.main import app

    app.dependency_overrides[get_firestore] = lambda: db
    return app


def test_admin_rejects_non_allowlisted_email():
    app = _client(_admin_db("someone@example.com"))
    with patch("app.routers.admin.get_current_user_id", new_callable=AsyncMock) as user:
        user.return_value = "google-user"
        with TestClient(app) as client:
            response = client.get("/admin/prompts/deployment")
    app.dependency_overrides.clear()

    assert response.status_code == 403


def test_admin_prompt_test_uses_prompt_override_and_logs():
    app = _client(_admin_db())
    with patch(
        "app.routers.admin.get_current_user_id",
        new_callable=AsyncMock,
    ) as user, patch(
        "app.routers.admin.coach_service.chat",
        new_callable=AsyncMock,
    ) as chat, patch(
        "app.routers.admin.prompt_service.log_prompt_test",
        new_callable=AsyncMock,
    ) as log_prompt_test:
        user.return_value = "google-user"
        chat.return_value = "返答です。"
        log_prompt_test.return_value = "log-1"

        with TestClient(app) as client:
            response = client.post(
                "/admin/prompts/test",
                json={"message": "hello", "prompt": "custom system"},
            )
    app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["data"]["message"] == "返答です。"
    chat.assert_awaited_once()
    assert chat.call_args.kwargs["system_prompt"] == "custom system"
    log_prompt_test.assert_awaited_once()


def test_admin_current_prompt_returns_internal_prompt_when_no_deployment():
    app = _client(_admin_db())
    with patch(
        "app.routers.admin.get_current_user_id",
        new_callable=AsyncMock,
    ) as user, patch(
        "app.routers.admin.prompt_service.get_active_config",
        new_callable=AsyncMock,
    ) as get_active_config:
        from app.services.prompt_service import default_config

        config = default_config()
        config["system_prompt"] = "internal system prompt"
        user.return_value = "google-user"
        get_active_config.return_value = (config, None)

        with TestClient(app) as client:
            response = client.get("/admin/prompts/current")
    app.dependency_overrides.clear()

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["prompt"] == "internal system prompt"
    assert data["version_id"] is None
    assert data["source"] == "internal"
    assert data["config"]["system_prompt"] == "internal system prompt"


def test_admin_auth_bypass_only_in_dev(monkeypatch):
    from app.config import settings

    monkeypatch.setattr(settings, "environment", "dev")
    monkeypatch.setattr(settings, "admin_auth_bypass", True)
    app = _client(_admin_db("someone@example.com"))
    with patch(
        "app.routers.admin.prompt_service.get_deployment",
        new_callable=AsyncMock,
    ) as get_deployment:
        get_deployment.return_value = {
            "environment": "dev",
            "version_id": None,
            "deployed_by": None,
            "deployed_at": None,
        }
        with TestClient(app) as client:
            response = client.get("/admin/prompts/deployment")
    app.dependency_overrides.clear()

    assert response.status_code == 200
