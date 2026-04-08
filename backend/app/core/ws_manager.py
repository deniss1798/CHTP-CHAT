import json
from collections import defaultdict

from fastapi import WebSocket


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
