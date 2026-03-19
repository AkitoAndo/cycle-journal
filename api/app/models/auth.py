"""Auth-related Pydantic models."""

from datetime import datetime

from pydantic import BaseModel


class VerifyTokenRequest(BaseModel):
    identity_token: str


class VerifyTokenData(BaseModel):
    user_id: str
    apple_user_id: str
    email: str | None = None
    is_new_user: bool
    created_at: datetime
