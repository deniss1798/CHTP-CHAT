from fastapi import HTTPException, status

from app.models.chat import Chat
from app.models.user import User


def require_chat_exists(chat: Chat | None) -> Chat:
    if chat is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat not found",
        )
    return chat


def require_group_chat(
    chat: Chat | None,
    *,
    detail: str = "Only group chats support this action",
) -> Chat:
    resolved_chat = require_chat_exists(chat)
    if resolved_chat.type != "group":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail,
        )
    return resolved_chat


def require_group_creator(chat: Chat, current_user: User) -> None:
    if chat.created_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only group creator can remove members",
        )
