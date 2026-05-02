import json

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect

from app.core.rate_limit import WS_CONNECT_RULE, rate_limiter, websocket_client_ip
from app.core.security import decode_ws_or_access_token
from app.core.ws_manager import inbox_manager

router = APIRouter(tags=["WebSocket"])


@router.websocket("/ws/inbox")
async def websocket_inbox(
    websocket: WebSocket,
    token: str = Query(...),
):
    """События для главного экрана (typing и др.) без открытого чата."""
    user_id: int | None = None
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
