"""Health endpoint tests."""


def test_health_returns_200(client):
    response = client.get("/health")
    assert response.status_code == 200

    data = response.json()
    assert data["status"] == "healthy"
    assert "timestamp" in data


def test_health_includes_stage(client):
    response = client.get("/health")
    data = response.json()
    assert "stage" in data
