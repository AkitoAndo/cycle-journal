"""Structured logging for Cloud Run.

Cloud Run は stdout に JSON を吐けば Cloud Logging が jsonPayload として記録し、
`severity` を level に、`logging.googleapis.com/trace` を Trace と紐付ける。
ContextVar で request_id / uid をリクエスト単位に持ち回り、すべての log line に
自動的に付与する（middleware と get_current_user 側で set する）。
"""

from __future__ import annotations

import json
import logging
import sys
from contextvars import ContextVar
from typing import Any

request_id_var: ContextVar[str | None] = ContextVar("request_id", default=None)
uid_var: ContextVar[str | None] = ContextVar("uid", default=None)

_STD_LOG_ATTRS = {
    "args", "asctime", "created", "exc_info", "exc_text", "filename", "funcName",
    "levelname", "levelno", "lineno", "message", "module", "msecs", "msg", "name",
    "pathname", "process", "processName", "relativeCreated", "stack_info", "thread",
    "threadName", "taskName",
}


class JsonFormatter(logging.Formatter):
    """Cloud Run friendly JSON formatter."""

    def __init__(self, project_id: str | None = None) -> None:
        super().__init__()
        self._project_id = project_id

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "severity": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
        }
        rid = request_id_var.get()
        if rid:
            payload["request_id"] = rid
            if self._project_id:
                payload["logging.googleapis.com/trace"] = (
                    f"projects/{self._project_id}/traces/{rid}"
                )
        uid = uid_var.get()
        if uid:
            payload["uid"] = uid
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        # extra=... で渡された任意の key-value を上に乗せる
        for key, value in record.__dict__.items():
            if key in _STD_LOG_ATTRS or key.startswith("_"):
                continue
            if key in payload:
                continue
            payload[key] = value
        return json.dumps(payload, ensure_ascii=False, default=str)


def setup_logging(level: str = "INFO", project_id: str | None = None) -> None:
    """root logger と uvicorn 系を JSON formatter に揃える."""
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter(project_id=project_id))

    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(level)

    # uvicorn は default で stderr に独自 handler を付けるため上書き。
    for name in ("uvicorn", "uvicorn.access", "uvicorn.error", "fastapi"):
        logger = logging.getLogger(name)
        logger.handlers = [handler]
        logger.propagate = False
        logger.setLevel(level)
