"""Reflection-related Pydantic models."""

from datetime import datetime

from pydantic import BaseModel, Field


class CreateReflectionRequest(BaseModel):
    what_i_did: str = Field(..., min_length=1)
    what_i_noticed: str = Field(..., min_length=1)
    what_i_want_to_try: str | None = None
    overall_feeling: str | None = None


class ReflectionData(BaseModel):
    reflection_id: str
    task_id: str
    what_i_did: str
    what_i_noticed: str
    what_i_want_to_try: str | None = None
    overall_feeling: str | None = None
    created_at: datetime
