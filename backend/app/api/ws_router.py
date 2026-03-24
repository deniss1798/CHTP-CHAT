from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.ws_manager import manager
from app.db.database import SessionLocal
from app.models.chat_member import ChatMember

router = APIRouter(tags=["WebSocket"])
settings = get_settings()


@router.websocket("/ws/chat/{chat_id}")
async def websocket_chat(
    websocket: WebSocket,
    chat_id: int,
    token: str = Query(...),
):
    db: Session = SessionLocal()

    try:
        try:
            payload = jwt.decode(
                token,
                settings.secret_key,
                algorithms=[settings.algorithm],
            )
            user_id = int(payload.get("sub"))
        except (JWTError, TypeError, ValueError):
            await websocket.close(code=1008)
            return

        member = (
            db.query(ChatMember)
            .filter(
                ChatMember.chat_id == chat_id,
                ChatMember.user_id == user_id,
            )
            .first()
        )

        if not member:
            await websocket.close(code=1008)
            return

        await manager.connect(chat_id, websocket)

        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(chat_id, websocket)
    finally:
        db.close()