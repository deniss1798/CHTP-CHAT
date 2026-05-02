import logging

from sqlalchemy.orm import Session

from app.application.messages.chat_recipients import (
    filter_recipients_excluding_chat_muted,
)
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
    push_recipients = filter_recipients_excluding_chat_muted(
        db, chat_id, recipient_user_ids
    )
    try:
        send_chat_message_push(
            db=db,
            chat_id=chat_id,
            sender_name=sender_name,
            recipient_user_ids=push_recipients,
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
