"""Auth-related Pydantic models."""

from datetime import datetime

from pydantic import BaseModel


class VerifyTokenRequest(BaseModel):
    identity_token: str


class GoogleVerifyRequest(BaseModel):
    id_token: str


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class VerifyTokenData(BaseModel):
    user_id: str
    apple_user_id: str | None = None
    google_user_id: str | None = None
    email: str | None = None
    is_new_user: bool
    created_at: datetime
    access_token: str
    refresh_token: str
    expires_in: int


class RefreshTokenData(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: int
