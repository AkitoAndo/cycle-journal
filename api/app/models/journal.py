"""Journal sync models."""

from datetime import datetime

from pydantic import BaseModel, Field


class JournalSyncItem(BaseModel):
    journal_id: str = Field(..., min_length=1)
    text: str = ""
    tags: list[str] = []
    entry_date: datetime
    deleted_at: datetime | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class JournalData(BaseModel):
    journal_id: str
    text: str = ""
    tags: list[str] = []
    entry_date: datetime
    deleted_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class JournalListData(BaseModel):
    journals: list[JournalData]
    total: int


class JournalSyncRequest(BaseModel):
    journals: list[JournalSyncItem] = []
    deleted_journal_ids: list[str] = []
    last_pulled_at: datetime | None = None


class JournalSyncData(BaseModel):
    journals: list[JournalData]
    server_time: datetime
    pushed_count: int
    pulled_count: int
    deleted_count: int
    conflict_count: int
