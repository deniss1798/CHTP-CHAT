from sqlalchemy.orm import Session

from app.application.chats.chat_listing import _build_chat_responses_batch
from app.domain.policies.chat_access import require_chat_member
from app.models.chat import Chat
from app.models.user import User
from app.schemas.chat_schema import ChatResponse


def update_member_chat_preferences(
    db: Session,
    *,
    chat_id: int,
    current_user: User,
    is_archived: bool | None = None,
    notifications_muted: bool | None = None,
) -> ChatResponse:
    row = require_chat_member(db, chat_id, current_user)
    if is_archived is not None:
        row.is_archived = is_archived
    if notifications_muted is not None:
        row.notifications_muted = notifications_muted
    db.add(row)
    db.commit()

    chat = db.query(Chat).filter(Chat.id == chat_id).first()
    if chat is None:
        raise ValueError("chat missing after update")
    built = _build_chat_responses_batch(db, [chat], current_user)
    if not built:
        raise ValueError("chat response build failed")
    return built[0]
