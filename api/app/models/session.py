"""Session-related Pydantic models."""

from datetime import datetime

from pydantic import BaseModel

from app.models.common import CycleElement


class MessageData(BaseModel):
    message_id: str
    role: str  # "user" | "assistant"
    content: str
    metadata: dict | None = None
    created_at: datetime


class SessionSummary(BaseModel):
    session_id: str
    title: str | None = None
    cycle_element: CycleElement | None = None
    message_count: int = 0
    last_message_at: datetime | None = None
    created_at: datetime


class SessionDetail(BaseModel):
    session_id: str
    title: str | None = None
    cycle_element: CycleElement | None = None
    has_diary_context: bool = False
    messages: list[MessageData] = []
    created_at: datetime
    updated_at: datetime


class CreateSessionRequest(BaseModel):
    title: str | None = None
    diary_content: str | None = None
    cycle_element: CycleElement | None = None


class SessionListData(BaseModel):
    sessions: list[SessionSummary]
    total: int
    limit: int
    offset: int
