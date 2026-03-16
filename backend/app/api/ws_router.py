from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db.database import SessionLocal
from app.models.chat_member import ChatMember
from app.models.user import User
from app.core.ws_manager import manager

router = APIRouter()


@router.websocket("/ws/chat/{chat_id}")
async def chat_ws(websocket: WebSocket, chat_id: int):
    token = websocket.query_params.get("token")

    if not token:
        await websocket.close(code=1008)
        return

    payload = decode_access_token(token)
    if payload is None:
        await websocket.close(code=1008)
        return

    user_id = payload.get("sub")
    if user_id is None:
        await websocket.close(code=1008)
        return

    db: Session = SessionLocal()
    try:
        user = db.query(User).filter(User.id == int(user_id)).first()
        if user is None:
            await websocket.close(code=1008)
            return

        chat_member = (
            db.query(ChatMember)
            .filter(
                ChatMember.chat_id == chat_id,
                ChatMember.user_id == int(user_id),
            )
            .first()
        )

        if chat_member is None:
            await websocket.close(code=1008)
            return

        await manager.connect(chat_id, websocket)

        try:
            while True:
                data = await websocket.receive_json()
                await manager.broadcast(chat_id, data)

        except WebSocketDisconnect:
            manager.disconnect(chat_id, websocket)

    finally:
        db.close()