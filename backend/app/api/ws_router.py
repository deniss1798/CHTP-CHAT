import json
from datetime import datetime, timezone

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.ws_manager import inbox_manager, manager
from app.db.database import SessionLocal
from app.models.chat_member import ChatMember
from app.models.user import User

router = APIRouter(tags=["WebSocket"])
settings = get_settings()

_CALL_SIGNAL_TYPES = frozenset(
    {
        "call_e2e_init",
        "call_e2e_ack",
        "call_e2e_offer",
        "call_e2e_answer",
        "call_e2e_ice",
        "call_e2e_hangup",
    }
)


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

        await manager.connect(chat_id, websocket, user_id)

        user_row = db.query(User).filter(User.id == user_id).first()
        if user_row:
            user_row.last_seen_at = datetime.now(timezone.utc)
            db.add(user_row)
            db.commit()

        while True:
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if not isinstance(data, dict):
                continue
            msg_type = data.get("type")
            if msg_type == "typing":
                sender_row = db.query(User).filter(User.id == user_id).first()
                typing_payload = {
                    "type": "typing",
                    "chat_id": chat_id,
                    "user_id": user_id,
                    "username": sender_row.username if sender_row else "",
                    "typing": bool(data.get("typing", True)),
                }
                await manager.broadcast_to_others(
                    chat_id,
                    typing_payload,
                    exclude_user_id=user_id,
                )
                member_ids = (
                    db.query(ChatMember.user_id)
                    .filter(ChatMember.chat_id == chat_id)
                    .all()
                )
                for (member_uid,) in member_ids:
                    if member_uid != user_id:
                        await inbox_manager.send_json(member_uid, typing_payload)
            elif msg_type in _CALL_SIGNAL_TYPES:
                call_payload = dict(data)
                call_payload["type"] = msg_type
                call_payload["chat_id"] = chat_id
                call_payload["user_id"] = user_id
                await manager.broadcast_to_others(
                    chat_id,
                    call_payload,
                    exclude_user_id=user_id,
                )
                member_ids = (
                    db.query(ChatMember.user_id)
                    .filter(ChatMember.chat_id == chat_id)
                    .all()
                )
                for (member_uid,) in member_ids:
                    if member_uid != user_id:
                        await inbox_manager.send_json(member_uid, call_payload)
    except WebSocketDisconnect:
        manager.disconnect(chat_id, websocket)
    finally:
        db.close()
