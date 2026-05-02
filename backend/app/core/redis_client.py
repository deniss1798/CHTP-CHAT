from __future__ import annotations

from functools import lru_cache

from app.core.config import get_settings

try:
    import redis
    import redis.asyncio as redis_async
except Exception:  # pragma: no cover - optional dependency in local tests
    redis = None
    redis_async = None


@lru_cache
def get_redis_client():
    settings = get_settings()
    if not settings.redis_url or redis is None:
        return None
    return redis.Redis.from_url(
        settings.redis_url,
        decode_responses=True,
        socket_timeout=settings.redis_socket_timeout_seconds,
        socket_connect_timeout=settings.redis_socket_connect_timeout_seconds,
    )


def make_async_redis_client():
    settings = get_settings()
    if not settings.redis_url or redis_async is None:
        return None
    return redis_async.Redis.from_url(
        settings.redis_url,
        decode_responses=True,
        socket_timeout=settings.redis_socket_timeout_seconds,
        socket_connect_timeout=settings.redis_socket_connect_timeout_seconds,
    )
