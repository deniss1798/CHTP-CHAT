"""Attach a stable request id for logs and client correlation (X-Request-ID)."""

import uuid
from collections.abc import Awaitable, Callable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

REQUEST_ID_HEADER = "X-Request-ID"
_MAX_INCOMING_LEN = 128

RequestIdNext = Callable[[Request], Awaitable[Response]]


class RequestIdMiddleware(BaseHTTPMiddleware):
    """Echo client `X-Request-ID` or generate UUID; set on response and `request.state`."""

    async def dispatch(self, request: Request, call_next: RequestIdNext) -> Response:
        raw = request.headers.get(REQUEST_ID_HEADER)
        if raw and str(raw).strip():
            rid = str(raw).strip()[:_MAX_INCOMING_LEN]
        else:
            rid = str(uuid.uuid4())
        request.state.request_id = rid
        response = await call_next(request)
        response.headers[REQUEST_ID_HEADER] = rid
        return response
