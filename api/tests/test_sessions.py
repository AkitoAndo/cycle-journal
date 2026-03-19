"""Session endpoint tests."""


def test_list_sessions_requires_auth(client):
    response = client.get("/sessions")
    assert response.status_code == 401


def test_create_session_requires_auth(client):
    response = client.post("/sessions", json={})
    assert response.status_code == 401
