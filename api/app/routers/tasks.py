"""Task endpoints - CRUD for tasks and reflections."""

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Query, Response
from google.cloud.firestore import AsyncClient

from app.dependencies import get_current_user, get_firestore
from app.exceptions import NotFoundError
from app.models.reflection import CreateReflectionRequest, ReflectionData
from app.models.task import CreateTaskRequest, TaskData, TaskListData, UpdateTaskRequest
from app.services.firestore_client import tasks_ref

router = APIRouter(prefix="/tasks", tags=["Tasks"])


@router.get("")
async def list_tasks(
    status: str | None = Query(default=None),
    limit: int = Query(default=20, le=100),
    offset: int = Query(default=0, ge=0),
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """ユーザーのタスク一覧を取得."""
    ref = tasks_ref(db)
    query = ref.where("user_id", "==", user_id)

    if status:
        query = query.where("status", "==", status)

    query = query.order_by("created_at", direction="DESCENDING")

    all_docs = [doc async for doc in query.stream()]
    total = len(all_docs)
    paginated = all_docs[offset : offset + limit]

    tasks = []
    for doc in paginated:
        data = doc.to_dict() or {}
        tasks.append(_doc_to_task(doc.id, data))

    return {
        "data": TaskListData(
            tasks=tasks,
            total=total,
            limit=limit,
            offset=offset,
        )
    }


@router.post("", status_code=201)
async def create_task(
    body: CreateTaskRequest,
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """新しいタスクを作成."""
    ref = tasks_ref(db)
    task_id = str(uuid.uuid4())
    now = datetime.now(UTC)

    task_data = {
        "user_id": user_id,
        "title": body.title,
        "description": body.description,
        "status": "pending",
        "session_id": body.session_id,
        "cycle_element": body.cycle_element.value if body.cycle_element else None,
        "due_date": body.due_date,
        "completed_at": None,
        "created_at": now,
        "updated_at": now,
    }
    await ref.document(task_id).set(task_data)

    return {"data": _doc_to_task(task_id, task_data)}


@router.put("/{task_id}")
async def update_task(
    task_id: str,
    body: UpdateTaskRequest,
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """タスクを更新."""
    ref = tasks_ref(db)
    doc = ref.document(task_id)
    snapshot = await doc.get()

    if not snapshot.exists:
        raise NotFoundError("Task")

    data = snapshot.to_dict() or {}
    if data.get("user_id") != user_id:
        raise NotFoundError("Task")

    now = datetime.now(UTC)
    updates: dict = {"updated_at": now}

    if body.title is not None:
        updates["title"] = body.title
    if body.description is not None:
        updates["description"] = body.description
    if body.status is not None:
        updates["status"] = body.status
        if body.status == "completed":
            updates["completed_at"] = now
    if body.due_date is not None:
        updates["due_date"] = body.due_date

    await doc.update(updates)

    updated_snap = await doc.get()
    return {"data": _doc_to_task(task_id, updated_snap.to_dict() or {})}


@router.delete("/{task_id}", status_code=204)
async def delete_task(
    task_id: str,
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """タスクを削除."""
    ref = tasks_ref(db)
    doc = ref.document(task_id)
    snapshot = await doc.get()

    if not snapshot.exists:
        raise NotFoundError("Task")

    data = snapshot.to_dict() or {}
    if data.get("user_id") != user_id:
        raise NotFoundError("Task")

    # サブコレクション（reflections）も削除
    reflections_ref = doc.collection("reflections")
    async for refl_doc in reflections_ref.stream():
        await refl_doc.reference.delete()

    await doc.delete()
    return Response(status_code=204)


@router.post("/{task_id}/reflection", status_code=201)
async def create_reflection(
    task_id: str,
    body: CreateReflectionRequest,
    user_id: str = Depends(get_current_user),
    db: AsyncClient = Depends(get_firestore),
):
    """タスクのふりかえりを登録."""
    ref = tasks_ref(db)
    doc = ref.document(task_id)
    snapshot = await doc.get()

    if not snapshot.exists:
        raise NotFoundError("Task")

    data = snapshot.to_dict() or {}
    if data.get("user_id") != user_id:
        raise NotFoundError("Task")

    reflection_id = str(uuid.uuid4())
    now = datetime.now(UTC)

    reflection_data = {
        "task_id": task_id,
        "what_i_did": body.what_i_did,
        "what_i_noticed": body.what_i_noticed,
        "what_i_want_to_try": body.what_i_want_to_try,
        "overall_feeling": body.overall_feeling,
        "created_at": now,
    }

    reflections_ref = doc.collection("reflections")
    await reflections_ref.document(reflection_id).set(reflection_data)

    return {
        "data": ReflectionData(
            reflection_id=reflection_id,
            task_id=task_id,
            what_i_did=body.what_i_did,
            what_i_noticed=body.what_i_noticed,
            what_i_want_to_try=body.what_i_want_to_try,
            overall_feeling=body.overall_feeling,
            created_at=now,
        )
    }


def _doc_to_task(task_id: str, data: dict) -> TaskData:
    return TaskData(
        task_id=task_id,
        title=data.get("title", ""),
        description=data.get("description"),
        status=data.get("status", "pending"),
        session_id=data.get("session_id"),
        cycle_element=data.get("cycle_element"),
        due_date=data.get("due_date"),
        completed_at=data.get("completed_at"),
        created_at=data.get("created_at"),
        updated_at=data.get("updated_at"),
    )
