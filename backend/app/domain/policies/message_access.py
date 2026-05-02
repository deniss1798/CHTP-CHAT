from fastapi import HTTPException, status

from app.models.message import Message
from app.models.user import User


def require_message_sender(message: Message, current_user: User) -> None:
    if message.sender_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can edit only your own messages",
        )


def require_message_sender_for_delete(message: Message, current_user: User) -> None:
    if message.sender_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can delete only your own messages",
        )
