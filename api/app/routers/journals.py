"""Journal endpoints - bidirectional local/server sync."""

from datetime import UTC, datetime

from fastapi import APIRouter, Depends
from google.cloud.firestore import AsyncClient

from app.dependencies import get_current_user, get_firestore
from app.exceptions import ValidationError
from app.models.journal import (
    JournalData,
    JournalListData,
    JournalSyncData,
    JournalSyncItem,
    JournalSyncRequest,
)
from app.services.firestore_client import journals_ref

router = APIRouter(prefix="/journals", tags=["Journals"])


@router.get("")
async def list_journals(
    include_deleted: bool = False,
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """Return all journals for the authenticated user."""
    docs = await _load_user_journals(db, user_id)
    journals = [
        _doc_to_journal(doc_id, data)
        for doc_id, data in docs
        if include_deleted or data.get("deleted_at") is None
    ]
    journals.sort(key=lambda item: item.entry_date, reverse=True)
    return {"data": JournalListData(journals=journals, total=len(journals))}


@router.post("/sync")
async def sync_journals(
    body: JournalSyncRequest,
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """Push local journals and return server journals changed since last pull.

    Conflict policy: last-write-wins using `updated_at` from each side. Ambiguous
    old local records use their entry date as the client update timestamp.
    """
    now = datetime.now(UTC)
    ref = journals_ref(db)
    pushed_count = 0
    deleted_count = 0
    conflict_count = 0

    seen_ids: set[str] = set()
    for item in body.journals:
        if item.journal_id in seen_ids:
            raise ValidationError("duplicate journal_id in sync payload")
        seen_ids.add(item.journal_id)

    for journal_id in body.deleted_journal_ids:
        if not journal_id:
            continue
        doc_ref = ref.document(journal_id)
        snapshot = await doc_ref.get()
        if snapshot.exists:
            data = snapshot.to_dict() or {}
            if data.get("user_id") != user_id:
                conflict_count += 1
                continue
            await doc_ref.update(
                {
                    "text": "",
                    "tags": [],
                    "deleted_at": now,
                    "updated_at": now,
                }
            )
            deleted_count += 1

    for item in body.journals:
        applied = await _apply_client_journal(ref, user_id, item, now)
        if applied == "pushed":
            pushed_count += 1
        elif applied == "conflict":
            conflict_count += 1

    docs = await _load_user_journals(db, user_id)
    journals = []
    for doc_id, data in docs:
        updated_at = data.get("updated_at")
        if body.last_pulled_at is not None and updated_at is not None:
            if _as_utc(updated_at) <= _as_utc(body.last_pulled_at):
                continue
        journals.append(_doc_to_journal(doc_id, data))
    journals.sort(key=lambda item: item.updated_at, reverse=True)

    return {
        "data": JournalSyncData(
            journals=journals,
            server_time=now,
            pushed_count=pushed_count,
            pulled_count=len(journals),
            deleted_count=deleted_count,
            conflict_count=conflict_count,
        )
    }


async def _apply_client_journal(
    ref,
    user_id: str,
    item: JournalSyncItem,
    now: datetime,
) -> str:
    doc_ref = ref.document(item.journal_id)
    snapshot = await doc_ref.get()
    client_updated_at = _as_utc(item.updated_at or item.created_at or item.entry_date)
    created_at = _as_utc(item.created_at or item.entry_date)

    if snapshot.exists:
        current = snapshot.to_dict() or {}
        if current.get("user_id") != user_id:
            return "conflict"
        server_updated_at = current.get("updated_at") or current.get("created_at")
        if (
            server_updated_at is not None
            and _as_utc(server_updated_at) > client_updated_at
        ):
            return "conflict"
        created_at = _as_utc(current.get("created_at") or created_at)

    await doc_ref.set(
        {
            "user_id": user_id,
            "text": item.text,
            "tags": item.tags,
            "entry_date": _as_utc(item.entry_date),
            "deleted_at": _as_utc(item.deleted_at) if item.deleted_at else None,
            "created_at": created_at,
            "updated_at": client_updated_at or now,
        }
    )
    return "pushed"


async def _load_user_journals(db: AsyncClient, user_id: str) -> list[tuple[str, dict]]:
    query = journals_ref(db).where("user_id", "==", user_id)
    docs: list[tuple[str, dict]] = []
    async for doc in query.stream():
        docs.append((doc.id, doc.to_dict() or {}))
    return docs


def _doc_to_journal(journal_id: str, data: dict) -> JournalData:
    entry_date = data.get("entry_date") or data.get("created_at") or datetime.now(UTC)
    created_at = data.get("created_at") or entry_date
    updated_at = data.get("updated_at") or created_at
    return JournalData(
        journal_id=journal_id,
        text=data.get("text") or "",
        tags=data.get("tags") or [],
        entry_date=_as_utc(entry_date),
        deleted_at=_as_utc(data["deleted_at"]) if data.get("deleted_at") else None,
        created_at=_as_utc(created_at),
        updated_at=_as_utc(updated_at),
    )


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
