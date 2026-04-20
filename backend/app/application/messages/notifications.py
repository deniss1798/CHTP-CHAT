import logging

from sqlalchemy.orm import Session

from app.application.messages.inbox_delivery import notify_inbox_new_message
from app.core.push_service import send_chat_message_push

logger = logging.getLogger(__name__)


async def deliver_new_message_notifications(
    db: Session,
    *,
    chat_id: int,
    sender_name: str,
    preview: str,
    recipient_user_ids: list[int],
) -> None:
    try:
        send_chat_message_push(
            db=db,
            chat_id=chat_id,
            sender_name=sender_name,
            recipient_user_ids=recipient_user_ids,
            message_text=preview,
        )
    except Exception:
        logger.exception("Push sending skipped for chat %s", chat_id)

    try:
        await notify_inbox_new_message(
            db,
            chat_id=chat_id,
            sender_name=sender_name,
            preview=preview,
            recipient_user_ids=recipient_user_ids,
        )
    except Exception:
        logger.exception("Inbox notify skipped for chat %s", chat_id)
