from __future__ import annotations

from dataclasses import dataclass
import time

from sqlalchemy import text

from app.core.redis_client import get_redis_client
from app.db.database import engine


@dataclass
class PushStats:
    send_success_total: int = 0
    send_error_total: int = 0
    send_timeout_total: int = 0
    invalid_token_total: int = 0


push_stats = PushStats()


def db_health() -> dict:
    start = time.perf_counter()
    try:
        with engine.connect() as connection:
            result = connection.execute(text("SELECT 1"))
            ok = result.scalar() == 1
        return {
            "ok": ok,
            "latency_ms": round((time.perf_counter() - start) * 1000.0, 2),
        }
    except Exception as exc:
        return {
            "ok": False,
            "latency_ms": round((time.perf_counter() - start) * 1000.0, 2),
            "error": exc.__class__.__name__,
        }


def redis_health() -> dict:
    client = get_redis_client()
    if client is None:
        return {"configured": False, "ok": False}
    start = time.perf_counter()
    try:
        ok = bool(client.ping())
        return {
            "configured": True,
            "ok": ok,
            "latency_ms": round((time.perf_counter() - start) * 1000.0, 2),
        }
    except Exception as exc:
        return {
            "configured": True,
            "ok": False,
            "latency_ms": round((time.perf_counter() - start) * 1000.0, 2),
            "error": exc.__class__.__name__,
        }
