"""User-related Pydantic models."""

from datetime import datetime

from pydantic import BaseModel


class UserSettings(BaseModel):
    notification_enabled: bool = False
    reminder_time: str | None = None


class UserData(BaseModel):
    user_id: str
    apple_user_id: str
    email: str | None = None
    display_name: str | None = None
    settings: UserSettings = UserSettings()
    created_at: datetime
    updated_at: datetime
