"""Coach-related Pydantic models."""

from pydantic import BaseModel, Field

from app.models.common import CycleElement


class CoachContext(BaseModel):
    cycle_element: CycleElement | None = None


class CoachRequest(BaseModel):
    message: str = Field(..., min_length=1)
    session_id: str | None = None
    diary_content: str | None = None
    context: CoachContext | None = None


class CoachMetadata(BaseModel):
    stage: str
    model: str
    cycle_element: CycleElement | None = None
    detected_emotion: str | None = None


class CoachData(BaseModel):
    message: str
    session_id: str
    metadata: CoachMetadata
