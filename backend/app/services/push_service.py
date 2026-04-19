"""Push и inbox-уведомления для сценариев сообщений."""

from sqlalchemy.orm import Session

from app.application.messages.inbox_delivery import notify_inbox_new_message
from app.core.push_service import send_chat_message_push


def try_send_chat_message_push(
    *,
    db: Session,
    chat_id: int,
    sender_name: str,
    recipient_user_ids: list[int],
    message_text: str,
) -> None:
    try:
        send_chat_message_push(
            db=db,
            chat_id=chat_id,
            sender_name=sender_name,
            recipient_user_ids=recipient_user_ids,
            message_text=message_text,
        )
    except Exception as e:
        print(f"Push sending skipped: {e}")


async def try_notify_inbox_new_message(
    *,
    db: Session,
    chat_id: int,
    sender_name: str,
    preview: str,
    recipient_user_ids: list[int],
) -> None:
    try:
        await notify_inbox_new_message(
            db,
            chat_id=chat_id,
            sender_name=sender_name,
            preview=preview,
            recipient_user_ids=recipient_user_ids,
        )
    except Exception as e:
        print(f"Inbox notify skipped: {e}")
