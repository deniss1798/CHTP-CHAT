from __future__ import annotations

import time
from collections import defaultdict, deque
from dataclasses import dataclass

from fastapi import HTTPException, Request, status

from app.core.config import get_settings
from app.core.redis_client import redis


@dataclass(frozen=True)
class RateLimitRule:
    name: str
    max_attempts: int
    window_seconds: int


class InMemoryRateLimiter:
    def __init__(self) -> None:
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def check(self, key: str, rule: RateLimitRule) -> None:
        now = time.monotonic()
        bucket_key = f"{rule.name}:{key}"
        hits = self._hits[bucket_key]
        cutoff = now - rule.window_seconds
        while hits and hits[0] <= cutoff:
            hits.popleft()

        if len(hits) >= rule.max_attempts:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests. Please try again later.",
            )

        hits.append(now)

    def clear(self) -> None:
        self._hits.clear()


class RedisRateLimiter:
    def __init__(self, url: str) -> None:
        settings = get_settings()
        if redis is None:
            raise RuntimeError("redis package is not installed")
        self._client = redis.Redis.from_url(
            url,
            decode_responses=True,
            socket_timeout=settings.redis_socket_timeout_seconds,
            socket_connect_timeout=settings.redis_socket_connect_timeout_seconds,
        )

    def check(self, key: str, rule: RateLimitRule) -> None:
        bucket_key = f"rate-limit:{rule.name}:{key}"
        pipe = self._client.pipeline()
        pipe.incr(bucket_key)
        pipe.expire(bucket_key, rule.window_seconds, nx=True)
        count, _ = pipe.execute()
        if int(count) > rule.max_attempts:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests. Please try again later.",
            )

    def clear(self) -> None:
        # Test helper only. Avoid scanning production Redis by default.
        pass


def _build_rate_limiter():
    redis_url = get_settings().redis_url
    if redis_url:
        return RedisRateLimiter(redis_url)
    return InMemoryRateLimiter()


rate_limiter = _build_rate_limiter()

AUTH_LOGIN_RULE = RateLimitRule("auth_login", max_attempts=5, window_seconds=600)
AUTH_REQUEST_CODE_RULE = RateLimitRule(
    "auth_request_email_code",
    max_attempts=3,
    window_seconds=600,
)
AUTH_VERIFY_CODE_RULE = RateLimitRule(
    "auth_verify_email_code",
    max_attempts=5,
    window_seconds=600,
)
MESSAGE_SEND_RULE = RateLimitRule("message_send", max_attempts=60, window_seconds=60)
MEDIA_UPLOAD_RULE = RateLimitRule("media_upload", max_attempts=30, window_seconds=60)
WS_CONNECT_RULE = RateLimitRule("ws_connect", max_attempts=30, window_seconds=60)


def client_ip(request: Request) -> str:
    forwarded_for = request.headers.get("x-forwarded-for", "").split(",")[0].strip()
    if forwarded_for:
        return forwarded_for
    if request.client is None:
        return "unknown"
    return request.client.host


def normalize_rate_key(value: str | None) -> str:
    return (value or "").strip().lower() or "unknown"


def websocket_client_ip(client) -> str:
    if client is None:
        return "unknown"
    return getattr(client, "host", None) or "unknown"
