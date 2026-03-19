"""Auth endpoint tests."""

from unittest.mock import AsyncMock, patch


def test_verify_missing_token(client):
    response = client.post("/auth/verify", json={"identity_token": ""})
    assert response.status_code in (400, 422)


def test_verify_valid_token(client, mock_firestore):
    """Test successful token verification."""
    with patch(
        "app.routers.auth.verify_apple_token",
        new_callable=AsyncMock,
    ) as mock_apple:
        mock_apple.return_value = {
            "sub": "apple-user-001",
            "email": "user@example.com",
        }

        response = client.post(
            "/auth/verify",
            json={"identity_token": "valid.jwt.token"},
        )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["user_id"] == "apple-user-001"
    assert data["is_new_user"] is True
