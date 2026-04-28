import logging
from collections import defaultdict
from collections.abc import Callable

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class InboxConnectionManager:
    """Одно соединение на пользователя: события для списка чатов (например typing)."""

    def __init__(self):
        self._user_id_to_ws: dict[int, WebSocket] = {}

    async def connect(self, user_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        self._user_id_to_ws[user_id] = websocket

    def disconnect(self, user_id: int, websocket: WebSocket) -> None:
        if self._user_id_to_ws.get(user_id) is websocket:
            del self._user_id_to_ws[user_id]

    async def send_json(self, user_id: int, message: dict) -> bool:
        """True, если сообщение ушло по WebSocket; False, если соединения не было."""
        ws = self._user_id_to_ws.get(user_id)
        if not ws:
            t = message.get("type")
            if isinstance(t, str) and (
                t.startswith("call_e2e_") or t.startswith("group_call_")
            ):
                logger.info(
                    "inbox_skip user_id=%s type=%s (нет активного /ws/inbox)",
                    user_id,
                    t,
                )
            return False
        try:
            await ws.send_json(message)
            return True
        except Exception:
            self.disconnect(user_id, ws)
            return False


class ConnectionManager:
    def __init__(self):
        # chat_id -> list of (websocket, user_id)
        self.active_connections: dict[int, list[tuple[WebSocket, int]]] = defaultdict(list)

    async def connect(self, chat_id: int, websocket: WebSocket, user_id: int):
        await websocket.accept()
        self.active_connections[chat_id].append((websocket, user_id))

    def disconnect(self, chat_id: int, websocket: WebSocket):
        conns = self.active_connections.get(chat_id)
        if not conns:
            return
        self.active_connections[chat_id] = [
            (ws, uid) for ws, uid in conns if ws is not websocket
        ]
        if not self.active_connections[chat_id]:
            del self.active_connections[chat_id]

    async def _send_json_safe(self, chat_id: int, websocket: WebSocket, message: dict) -> None:
        try:
            await websocket.send_json(message)
        except Exception:
            self.disconnect(chat_id, websocket)

    async def broadcast(self, chat_id: int, message: dict):
        conns = list(self.active_connections.get(chat_id, []))
        for connection, _ in conns:
            await self._send_json_safe(chat_id, connection, message)

    async def broadcast_personalized(
        self,
        chat_id: int,
        message_builder: Callable[[int], dict],
    ) -> None:
        conns = list(self.active_connections.get(chat_id, []))
        for ws, uid in conns:
            msg = message_builder(uid)
            await self._send_json_safe(chat_id, ws, msg)

    async def broadcast_to_others(
        self,
        chat_id: int,
        message: dict,
        exclude_user_id: int,
    ):
        conns = list(self.active_connections.get(chat_id, []))
        for connection, uid in conns:
            if uid == exclude_user_id:
                continue
            await self._send_json_safe(chat_id, connection, message)


manager = ConnectionManager()
inbox_manager = InboxConnectionManager()
