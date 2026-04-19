from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.chat_member import ChatMember
from app.models.user import User


def require_chat_member(db: Session, chat_id: int, user: User) -> ChatMember:
    """Raise 403 if the user is not a member of the chat; otherwise return membership row."""
    row = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == user.id,
        )
        .first()
    )
    if not row:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this chat",
        )
    return row
