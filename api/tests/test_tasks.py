"""Task endpoint tests."""


def test_list_tasks_requires_auth(client):
    response = client.get("/tasks")
    assert response.status_code == 401


def test_create_task_requires_auth(client):
    response = client.post("/tasks", json={"title": "Test"})
    assert response.status_code == 401
