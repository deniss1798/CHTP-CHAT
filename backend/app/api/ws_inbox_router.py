import json

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from jose import JWTError, jwt

from app.core.config import get_settings
from app.core.ws_manager import inbox_manager

router = APIRouter(tags=["WebSocket"])
settings = get_settings()


@router.websocket("/ws/inbox")
async def websocket_inbox(
    websocket: WebSocket,
    token: str = Query(...),
):
    """События для главного экрана (typing и др.) без открытого чата."""
    user_id: int | None = None
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

        await inbox_manager.connect(user_id, websocket)

        while True:
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if isinstance(data, dict) and data.get("type") == "ping":
                try:
                    await websocket.send_json({"type": "pong"})
                except Exception:
                    break
    except WebSocketDisconnect:
        pass
    finally:
        if user_id is not None:
            inbox_manager.disconnect(user_id, websocket)
