import pytest
from fastapi import HTTPException

from app.domain.policies.group_chat_policy import (
    require_chat_exists,
    require_group_chat,
    require_group_creator,
)
from app.models.chat import Chat
from app.models.user import User


def _build_user(user_id: int) -> User:
    return User(
        id=user_id,
        username=f"user-{user_id}",
        email=f"user-{user_id}@example.com",
        password_hash="secret",
    )


def test_require_chat_exists_returns_chat() -> None:
    chat = Chat(id=10, type="group", title="Team", created_by=1)

    assert require_chat_exists(chat) is chat


def test_require_chat_exists_raises_404_for_missing_chat() -> None:
    with pytest.raises(HTTPException) as exc_info:
        require_chat_exists(None)

    assert exc_info.value.status_code == 404
    assert exc_info.value.detail == "Chat not found"


def test_require_group_chat_rejects_private_chat() -> None:
    private_chat = Chat(id=10, type="private", created_by=1)

    with pytest.raises(HTTPException) as exc_info:
        require_group_chat(private_chat, detail="Only group chats can be renamed")

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail == "Only group chats can be renamed"


def test_require_group_creator_rejects_non_creator() -> None:
    chat = Chat(id=10, type="group", created_by=1)
    current_user = _build_user(2)

    with pytest.raises(HTTPException) as exc_info:
        require_group_creator(chat, current_user)

    assert exc_info.value.status_code == 403
    assert exc_info.value.detail == "Only group creator can remove members"
