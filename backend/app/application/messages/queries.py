from sqlalchemy.orm import Session

from app.application.messages.message_projection import (
    apply_private_media_urls,
    apply_private_media_urls_map,
    make_s3_getter,
    message_to_response_batched,
)
from app.domain.policies.chat_access import require_chat_member
from app.models.message import Message
from app.models.user import User
from app.repositories.messages_repository import MessagesRepository
from app.schemas.message_schema import MessageResponse


def list_chat_messages(
    db: Session,
    *,
    current_user: User,
    chat_id: int,
) -> list[MessageResponse]:
    repo = MessagesRepository(db)
    require_chat_member(db, chat_id, current_user)

    messages = repo.list_for_chat_ordered(chat_id)
    messages = apply_private_media_urls(messages)

    reply_ids = [message.reply_to_message_id for message in messages if message.reply_to_message_id]
    parents_by_id: dict[int, Message] = {}

    if reply_ids:
        parents = repo.list_by_ids(reply_ids)
        apply_private_media_urls_map(parents)
        for parent in parents:
            parents_by_id[parent.id] = parent

    get_storage = make_s3_getter()

    return [
        message_to_response_batched(
            message,
            parents_by_id,
            get_storage,
            db,
            current_user.id,
        )
        for message in messages
    ]
