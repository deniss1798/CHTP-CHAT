"""Optional request duration logging (roadmap: measure key endpoints in prod-like runs)."""

import json
import logging
import time
from collections.abc import Awaitable, Callable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger("perf")

PerfNext = Callable[[Request], Awaitable[Response]]


class RequestTimingMiddleware(BaseHTTPMiddleware):
    """When enabled, logs JSON with method/path/status/duration and sets X-Response-Time-Ms."""

    def __init__(self, app, *, enabled: bool) -> None:
        super().__init__(app)
        self._enabled = enabled

    async def dispatch(
        self, request: Request, call_next: PerfNext
    ) -> Response:
        if not self._enabled:
            return await call_next(request)

        start = time.perf_counter()
        response = await call_next(request)
        duration_ms = (time.perf_counter() - start) * 1000.0
        response.headers["X-Response-Time-Ms"] = f"{duration_ms:.2f}"
        # Response body size: Starlette may not have finalized Content-Length; log path only.
        rid = getattr(request.state, "request_id", None)
        msg: dict = {
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "duration_ms": round(duration_ms, 2),
        }
        if rid:
            msg["request_id"] = str(rid)
        try:
            logger.info(json.dumps(msg, ensure_ascii=False))
        except Exception:
            pass
        return response
