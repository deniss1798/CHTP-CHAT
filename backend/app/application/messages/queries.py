from sqlalchemy.orm import Session

from app.application.messages.message_projection import (
    apply_private_media_urls,
    apply_private_media_urls_map,
    make_s3_getter,
    message_to_response_batched,
)
from app.application.messages.reaction_service import reaction_groups_for_messages
from app.domain.policies.chat_access import require_chat_member
from app.models.message import Message
from app.models.user import User
from app.repositories.messages_repository import MessagesRepository
from app.schemas.message_schema import MessageListPage, MessageResponse

_DEFAULT_PAGE = 50
_MAX_PAGE = 100


def list_chat_messages(
    db: Session,
    *,
    current_user: User,
    chat_id: int,
    before_message_id: int | None = None,
    limit: int | None = None,
) -> MessageListPage:
    repo = MessagesRepository(db)
    require_chat_member(db, chat_id, current_user)

    lim = limit if limit is not None else _DEFAULT_PAGE
    lim = max(1, min(lim, _MAX_PAGE))

    if before_message_id is None:
        page_rows = repo.list_latest_for_chat(chat_id, lim + 1)
    else:
        page_rows = repo.list_older_than(chat_id, before_message_id, lim + 1)

    has_more = len(page_rows) > lim
    messages = page_rows[:lim]
    messages = apply_private_media_urls(messages)

    reply_ids = [message.reply_to_message_id for message in messages if message.reply_to_message_id]
    parents_by_id: dict[int, Message] = {}

    if reply_ids:
        parents = repo.list_by_ids(reply_ids)
        apply_private_media_urls_map(parents)
        for parent in parents:
            parents_by_id[parent.id] = parent

    get_storage = make_s3_getter()

    react_map = reaction_groups_for_messages(
        db, [m.id for m in messages], current_user.id
    )

    out = [
        message_to_response_batched(
            message,
            parents_by_id,
            get_storage,
            db,
            current_user.id,
            reactions=react_map.get(message.id, []),
        )
        for message in messages
    ]

    return MessageListPage(messages=out, has_more=has_more)
