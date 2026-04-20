from app.application.realtime.ws_event_names import (
    WS_EVENT_MESSAGE_DELETED,
    WS_EVENT_MESSAGE_UPDATED,
    WS_TYPE_NEW_MESSAGE,
    WS_TYPE_READ_RECEIPT,
)
from app.core.ws_manager import manager


async def publish_new_message(chat_id: int, message: dict) -> None:
    await manager.broadcast(
        chat_id,
        {"type": WS_TYPE_NEW_MESSAGE, "message": message},
    )


async def publish_message_updated(chat_id: int, message: dict) -> None:
    await manager.broadcast(
        chat_id,
        {"event": WS_EVENT_MESSAGE_UPDATED, "message": message},
    )


async def publish_message_deleted(chat_id: int, *, message_id: int) -> None:
    await manager.broadcast(
        chat_id,
        {
            "event": WS_EVENT_MESSAGE_DELETED,
            "id": message_id,
            "chat_id": chat_id,
        },
    )


async def publish_read_receipt(
    chat_id: int,
    *,
    user_id: int,
    last_read_message_id: int | None,
) -> None:
    await manager.broadcast(
        chat_id,
        {
            "type": WS_TYPE_READ_RECEIPT,
            "chat_id": chat_id,
            "user_id": user_id,
            "last_read_message_id": last_read_message_id,
        },
    )
