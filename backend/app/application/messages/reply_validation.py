from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.message import Message


def validate_reply_target(
    db: Session, chat_id: int, reply_to_message_id: int | None
) -> None:
    if reply_to_message_id is None:
        return

    parent = db.query(Message).filter(Message.id == reply_to_message_id).first()

    if not parent or parent.chat_id != chat_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid reply target",
        )
