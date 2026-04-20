from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.application.realtime.chat_events import publish_read_receipt
from app.domain.policies.chat_access import require_chat_member
from app.models.message import Message
from app.models.user import User


async def mark_chat_read(
    db: Session,
    *,
    chat_id: int,
    current_user: User,
    message_id: int,
) -> dict[str, int | str | None]:
    member = require_chat_member(db, chat_id, current_user)

    message = (
        db.query(Message)
        .filter(Message.id == message_id, Message.chat_id == chat_id)
        .first()
    )
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message not found",
        )

    previous_last_read = member.last_read_message_id or 0
    if message_id > previous_last_read:
        member.last_read_message_id = message_id
        db.commit()
        db.refresh(member)

        await publish_read_receipt(
            chat_id,
            user_id=current_user.id,
            last_read_message_id=member.last_read_message_id,
        )

    return {
        "detail": "ok",
        "last_read_message_id": member.last_read_message_id,
    }
