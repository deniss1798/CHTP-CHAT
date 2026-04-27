import json
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.application.realtime.event_payload import realtime_event
from app.core.rate_limit import WS_CONNECT_RULE, rate_limiter, websocket_client_ip
from app.core.security import decode_ws_or_access_token
from app.core.ws_manager import inbox_manager, manager
from app.db.database import SessionLocal
from app.models.chat_member import ChatMember
from app.models.user import User

router = APIRouter(tags=["WebSocket"])
logger = logging.getLogger(__name__)

_CALL_SIGNAL_TYPES = frozenset(
    {
        "call_e2e_init",
        "call_e2e_ack",
        "call_e2e_offer",
        "call_e2e_answer",
        "call_e2e_ice",
        "call_e2e_hangup",
        # Групповой звонок (mesh): сигналинг идёт через тот же WS, без E2E SDP.
        "group_call_invite",
        "group_call_join",
        "group_call_sdp",
        "group_call_ice",
        "group_call_leave",
        "group_call_end",
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
            payload = decode_ws_or_access_token(token)
            if payload is None:
                raise ValueError("invalid websocket token")
            user_id = int(payload.get("sub"))
            rate_limiter.check(
                f"{websocket_client_ip(websocket.client)}:{user_id}",
                WS_CONNECT_RULE,
            )
        except (TypeError, ValueError):
            await websocket.close(code=1008)
            return
        except Exception as exc:
            if getattr(exc, "status_code", None) == 429:
                await websocket.close(code=1013)
                return
            raise

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
                typing_payload = realtime_event({
                    "type": "typing",
                    "chat_id": chat_id,
                    "user_id": user_id,
                    "username": sender_row.username if sender_row else "",
                    "typing": bool(data.get("typing", True)),
                })
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
                call_payload = realtime_event(call_payload)
                logger.info(
                    "ws_call_signal chat_id=%s type=%s from_user=%s call_id=%s",
                    chat_id,
                    msg_type,
                    user_id,
                    data.get("call_id"),
                )
                await manager.broadcast_to_others(
                    chat_id,
                    call_payload,
                    exclude_user_id=user_id,
                )
                # SDP/ICE не дублируем в inbox: при открытом чате + inbox — двойная доставка
                # ломает WebRTC (setRemoteDescription, обрыв медиа).
                if msg_type not in ("group_call_sdp", "group_call_ice"):
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
