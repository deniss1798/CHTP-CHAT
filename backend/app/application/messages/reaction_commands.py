from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.application.messages.message_projection import message_to_response
from app.application.realtime.chat_events import publish_message_reactions_updated
from app.domain.policies.chat_access import require_chat_member
from app.models.message_reaction import MessageReaction
from app.models.user import User
from app.repositories.messages_repository import MessagesRepository


def _normalize_emoji(raw: str) -> str:
    e = raw.strip()
    if not e or len(e) > 32:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid emoji",
        )
    return e


async def add_message_reaction(
    db: Session,
    *,
    current_user: User,
    message_id: int,
    emoji: str,
):
    emoji = _normalize_emoji(emoji)
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
            detail="Deleted messages cannot have reactions",
        )

    row = MessageReaction(
        message_id=message_id,
        user_id=current_user.id,
        emoji=emoji,
    )
    db.add(row)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Reaction already exists",
        )

    db.refresh(message)
    await publish_message_reactions_updated(message.chat_id, message_id, db)
    return message_to_response(message, db, viewer_user_id=current_user.id)


async def remove_message_reaction(
    db: Session,
    *,
    current_user: User,
    message_id: int,
    emoji: str,
):
    emoji = _normalize_emoji(emoji)
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
            detail="Deleted messages cannot have reactions",
        )

    deleted = (
        db.query(MessageReaction)
        .filter(
            MessageReaction.message_id == message_id,
            MessageReaction.user_id == current_user.id,
            MessageReaction.emoji == emoji,
        )
        .delete()
    )
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reaction not found",
        )
    db.commit()

    db.refresh(message)
    await publish_message_reactions_updated(message.chat_id, message_id, db)
    return message_to_response(message, db, viewer_user_id=current_user.id)
