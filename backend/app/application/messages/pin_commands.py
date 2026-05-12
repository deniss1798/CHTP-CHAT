from datetime import datetime

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.application.messages.message_projection import (
    build_message_payload,
    message_to_response,
)
from app.application.realtime.chat_events import publish_message_pin_updated
from app.domain.policies.chat_access import require_chat_member
from app.models.message import Message
from app.models.user import User
from app.repositories.messages_repository import MessagesRepository
from app.schemas.message_schema import MessageResponse


async def pin_message(
    db: Session,
    *,
    current_user: User,
    message_id: int,
) -> MessageResponse:
    repo = MessagesRepository(db)
    message = repo.get_by_id(message_id)
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message not found",
        )
    require_chat_member(db, message.chat_id, current_user)
    if bool(getattr(message, "is_deleted", False)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Deleted messages cannot be pinned",
        )

    if message.pinned_at is None:
        message.pinned_at = datetime.utcnow()
        message.pinned_by_user_id = current_user.id
        repo.commit_refresh(message)

    await publish_message_pin_updated(
        message.chat_id,
        build_message_payload(message, db),
    )
    return message_to_response(message, db, viewer_user_id=current_user.id)


async def unpin_message(
    db: Session,
    *,
    current_user: User,
    message_id: int,
) -> MessageResponse:
    repo = MessagesRepository(db)
    message = repo.get_by_id(message_id)
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message not found",
        )
    require_chat_member(db, message.chat_id, current_user)

    if message.pinned_at is not None:
        message.pinned_at = None
        message.pinned_by_user_id = None
        repo.commit_refresh(message)

    await publish_message_pin_updated(
        message.chat_id,
        build_message_payload(message, db),
    )
    return message_to_response(message, db, viewer_user_id=current_user.id)


def list_pinned_messages(
    db: Session,
    *,
    current_user: User,
    chat_id: int,
) -> list[MessageResponse]:
    require_chat_member(db, chat_id, current_user)
    rows = (
        db.query(Message)
        .filter(
            Message.chat_id == chat_id,
            Message.pinned_at.isnot(None),
            Message.is_deleted.is_(False),
        )
        .order_by(Message.pinned_at.desc(), Message.id.desc())
        .limit(100)
        .all()
    )
    return [
        message_to_response(message, db, viewer_user_id=current_user.id)
        for message in rows
    ]
