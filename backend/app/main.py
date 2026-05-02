from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app.api.auth_router import router as auth_router
from app.api.calls_router import router as calls_router
from app.api.devices_router import router as devices_router
from app.api.notification_settings_router import router as notification_settings_router
from app.api.routers.chats.router import router as chats_router
from app.api.routers.messages.router import router as messages_router
from app.api.users_router import router as users_router
from app.api.ws_inbox_router import router as ws_inbox_router
from app.api.stories_router import router as stories_router
from app.api.webrtc_router import router as webrtc_router
from app.api.ws_router import router as ws_router
from app.core.config import get_settings
from app.core.log_redaction import install_log_redaction
from app.core.observability import db_health, push_stats, redis_health
from app.core.perf_middleware import RequestTimingMiddleware
from app.core.realtime_bus import bus_metrics, start_realtime_bus, stop_realtime_bus
from app.core.request_id_middleware import RequestIdMiddleware
from app.core.ws_manager import realtime_stats
from app.db.database import engine

settings = get_settings()
install_log_redaction()

app = FastAPI(title=settings.app_name)

if settings.perf_log_requests:
    app.add_middleware(RequestTimingMiddleware, enabled=True)

BASE_DIR = Path(__file__).resolve().parent.parent
MEDIA_DIR = BASE_DIR / "media"

MEDIA_DIR.mkdir(parents=True, exist_ok=True)
(MEDIA_DIR / "avatars").mkdir(parents=True, exist_ok=True)
(MEDIA_DIR / "avatars" / "users").mkdir(parents=True, exist_ok=True)
(MEDIA_DIR / "avatars" / "chats").mkdir(parents=True, exist_ok=True)

app.mount("/media", StaticFiles(directory=str(MEDIA_DIR)), name="media")

origins = [item.strip() for item in settings.cors_origins.split(",") if item.strip()]

if origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["X-Request-ID", "X-Response-Time-Ms"],
    )

# Outermost in add_middleware stack: first to see the request, last on response.
app.add_middleware(RequestIdMiddleware)


@app.on_event("startup")
async def startup_realtime_bus() -> None:
    await start_realtime_bus()


@app.on_event("shutdown")
async def shutdown_realtime_bus() -> None:
    await stop_realtime_bus()


@app.middleware("http")
async def add_security_headers(request, call_next):
    response = await call_next(request)
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Referrer-Policy", "no-referrer")
    response.headers.setdefault("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
    return response


@app.get("/")
def root():
    return {"message": "Messenger backend is running"}


@app.get("/health")
def health():
    return {"status": "ok"}


def _db_ready() -> bool:
    try:
        with engine.connect() as connection:
            result = connection.execute(text("SELECT 1"))
            return result.scalar() == 1
    except Exception:
        return False


@app.get("/ready")
@app.get("/api/ready")
def ready():
    """Liveness: use /health. Readiness: DB up (e.g. k8s readinessProbe)."""
    if not _db_ready():
        raise HTTPException(status_code=503, detail="not_ready")
    return {"status": "ready"}


@app.get("/metrics/realtime")
@app.get("/api/metrics/realtime")
def realtime_metrics():
    return {
        "chat_connections": realtime_stats.chat_connections,
        "inbox_connections": realtime_stats.inbox_connections,
        "chat_connect_total": realtime_stats.chat_connect_total,
        "inbox_connect_total": realtime_stats.inbox_connect_total,
        "chat_disconnect_total": realtime_stats.chat_disconnect_total,
        "inbox_disconnect_total": realtime_stats.inbox_disconnect_total,
        "send_error_total": realtime_stats.send_error_total,
        "redis_bus": bus_metrics(),
    }


@app.get("/metrics/system")
@app.get("/api/metrics/system")
def system_metrics():
    return {
        "db": db_health(),
        "redis": redis_health(),
        "realtime": realtime_metrics(),
        "push": {
            "send_success_total": push_stats.send_success_total,
            "send_error_total": push_stats.send_error_total,
            "send_timeout_total": push_stats.send_timeout_total,
            "invalid_token_total": push_stats.invalid_token_total,
        },
    }


@app.get("/db-check")
def db_check():
    with engine.connect() as connection:
        result = connection.execute(text("SELECT 1"))
        value = result.scalar()

    return {"database_connected": value == 1}


# Два набора путей: без префикса (прямой Uvicorn / nginx с rewrite) и с /api
# (когда клиент: API_BASE_URL=https://host/api — см. mobile_app ApiClient).
def _include_all_routers(prefix: str = "") -> None:
    kwargs = {"prefix": prefix} if prefix else {}
    app.include_router(users_router, **kwargs)
    app.include_router(auth_router, **kwargs)
    app.include_router(chats_router, **kwargs)
    app.include_router(messages_router, **kwargs)
    app.include_router(ws_router, **kwargs)
    app.include_router(ws_inbox_router, **kwargs)
    app.include_router(devices_router, **kwargs)
    app.include_router(calls_router, **kwargs)
    app.include_router(notification_settings_router, **kwargs)
    app.include_router(webrtc_router, **kwargs)
    app.include_router(stories_router, **kwargs)


_include_all_routers()
_include_all_routers("/api")
