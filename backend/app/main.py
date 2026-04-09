from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.api.auth_router import router as auth_router
from app.api.chats_router import router as chats_router
from app.api.devices_router import router as devices_router
from app.api.messages_router import router as messages_router
from app.api.users_router import router as users_router
from app.api.ws_inbox_router import router as ws_inbox_router
from app.api.ws_router import router as ws_router
from app.core.config import get_settings
from app.db.database import engine
from pathlib import Path
from fastapi.staticfiles import StaticFiles

settings = get_settings()

app = FastAPI(title=settings.app_name)

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
    )


@app.get("/")
def root():
    return {"message": "Messenger backend is running"}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/db-check")
def db_check():
    with engine.connect() as connection:
        result = connection.execute(text("SELECT 1"))
        value = result.scalar()

    return {"database_connected": value == 1}


app.include_router(users_router)
app.include_router(auth_router)
app.include_router(chats_router)
app.include_router(messages_router)
app.include_router(ws_router)
app.include_router(ws_inbox_router)
app.include_router(devices_router)