"""Task-related Pydantic models."""

from datetime import datetime

from pydantic import BaseModel, Field

from app.models.common import CycleElement


class CreateTaskRequest(BaseModel):
    title: str = Field(..., min_length=1)
    description: str | None = None
    session_id: str | None = None
    cycle_element: CycleElement | None = None
    due_date: datetime | None = None


class UpdateTaskRequest(BaseModel):
    title: str | None = None
    description: str | None = None
    status: str | None = None  # "pending" | "completed"
    due_date: datetime | None = None


class TaskData(BaseModel):
    task_id: str
    title: str
    description: str | None = None
    status: str = "pending"
    session_id: str | None = None
    cycle_element: CycleElement | None = None
    due_date: datetime | None = None
    completed_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class TaskListData(BaseModel):
    tasks: list[TaskData]
    total: int
    limit: int
    offset: int
