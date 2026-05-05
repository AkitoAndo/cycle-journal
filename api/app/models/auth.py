"""Auth-related Pydantic models."""

from datetime import datetime

from pydantic import BaseModel


class VerifyTokenRequest(BaseModel):
    identity_token: str
    # iOS から `ASAuthorizationAppleIDCredential.authorizationCode` を base64/utf8 で送る。
    # 受け取った場合はサーバ側で Apple refresh_token に交換し、アカウント削除時の
    # revoke 用に保存する。任意フィールド（無くてもサインインは成立する）。
    authorization_code: str | None = None


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
