"""Request ID middleware.

Cloud Run は X-Cloud-Trace-Context: TRACE_ID/SPAN_ID;o=1 を付ける。
それがあれば TRACE_ID を request_id として再利用する（Cloud Trace と紐づく）。
無ければクライアントの X-Request-ID か uuid を使う。
"""

from __future__ import annotations

import logging
import time
import uuid
from collections.abc import Awaitable, Callable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.logging_config import request_id_var

logger = logging.getLogger("app.request")


def _extract_request_id(request: Request) -> str:
    trace = request.headers.get("X-Cloud-Trace-Context", "")
    if "/" in trace:
        return trace.split("/", 1)[0]
    return request.headers.get("X-Request-ID") or uuid.uuid4().hex


class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        rid = _extract_request_id(request)
        token = request_id_var.set(rid)
        start = time.perf_counter()
        status = 500
        try:
            response = await call_next(request)
            status = response.status_code
            response.headers["X-Request-ID"] = rid
            return response
        finally:
            elapsed_ms = (time.perf_counter() - start) * 1000
            logger.info(
                "http_request",
                extra={
                    "method": request.method,
                    "path": request.url.path,
                    "status": status,
                    "elapsed_ms": round(elapsed_ms, 2),
                },
            )
            request_id_var.reset(token)
