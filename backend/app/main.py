from fastapi import FastAPI
from sqlalchemy import text
from app.api.chats_router import router as chats_router
from app.db.database import engine
from app.api.users_router import router as users_router
from app.api.auth_router import router as auth_router
from app.api.messages_router import router as messages_router
from app.api.ws_router import router as ws_router

app = FastAPI()


@app.get("/")
def root():
    return {"message": "Messenger backend is running"}


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