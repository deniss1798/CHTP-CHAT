"""Публикация событий в комнату чата (WebSocket)."""

from app.application.realtime.chat_events import (
    publish_message_deleted,
    publish_message_updated,
    publish_new_message,
)


async def broadcast_new_message(chat_id: int, message: dict) -> None:
    await publish_new_message(chat_id, message)


async def broadcast_message_updated(chat_id: int, message: dict) -> None:
    await publish_message_updated(chat_id, message)


async def broadcast_message_deleted(chat_id: int, *, message_id: int) -> None:
    await publish_message_deleted(chat_id, message_id=message_id)
