import asyncio

import pytest
from fastapi import HTTPException

from app.application.messages.commands import delete_message, update_text_message
from app.application.messages.message_projection import (
    DELETED_MESSAGE_TEXT,
    message_to_response,
)
from app.application.messages.reaction_commands import add_message_reaction
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.message import Message
from app.models.user import User
from app.schemas.message_schema import MessageUpdate


def _user(user_id: int, username: str) -> User:
    return User(
        id=user_id,
        username=username,
        email=f"{username}@example.com",
        password_hash="hash",
    )


def _seed_chat_with_message(db_session) -> tuple[User, User, Message]:
    alice = _user(1, "alice")
    bob = _user(2, "bob")
    chat = Chat(id=10, type="private", title="bob", created_by=1)
    message = Message(
        id=100,
        chat_id=10,
        sender_id=1,
        text="hello",
        message_type="text",
        is_updated=False,
        is_deleted=False,
    )
    db_session.add_all(
        [
            alice,
            bob,
            chat,
            ChatMember(id=1001, chat_id=10, user_id=1, role="owner"),
            ChatMember(id=1002, chat_id=10, user_id=2, role="member"),
            message,
        ]
    )
    db_session.commit()
    return alice, bob, message


def test_delete_message_soft_deletes_and_projection_masks_content(
    db_session,
    monkeypatch,
) -> None:
    alice, _, message = _seed_chat_with_message(db_session)
    published_updates: list[dict] = []
    published_deletes: list[int] = []

    async def fake_updated(chat_id: int, message_payload: dict) -> None:
        published_updates.append(message_payload)

    async def fake_deleted(chat_id: int, *, message_id: int) -> None:
        published_deletes.append(message_id)

    monkeypatch.setattr("app.application.messages.commands.publish_message_updated", fake_updated)
    monkeypatch.setattr("app.application.messages.commands.publish_message_deleted", fake_deleted)

    result = asyncio.run(
        delete_message(db_session, current_user=alice, message_id=message.id)
    )

    db_session.refresh(message)
    response = message_to_response(message, db_session, viewer_user_id=alice.id)

    assert result == {"detail": "Message deleted"}
    assert message.is_deleted is True
    assert message.text == DELETED_MESSAGE_TEXT
    assert response.text == DELETED_MESSAGE_TEXT
    assert response.message_type == "deleted"
    assert response.is_deleted is True
    assert published_updates[-1]["is_deleted"] is True
    assert published_deletes == [message.id]


def test_deleted_message_cannot_be_edited_or_reacted(db_session) -> None:
    alice, _, message = _seed_chat_with_message(db_session)
    message.is_deleted = True
    message.message_type = "deleted"
    message.text = DELETED_MESSAGE_TEXT
    db_session.commit()

    with pytest.raises(HTTPException) as edit_exc:
        asyncio.run(
            update_text_message(
                db_session,
                current_user=alice,
                message_id=message.id,
                payload=MessageUpdate(text="new text"),
            )
        )

    assert edit_exc.value.status_code == 400

    with pytest.raises(HTTPException) as reaction_exc:
        asyncio.run(
            add_message_reaction(
                db_session,
                current_user=alice,
                message_id=message.id,
                emoji="👍",
            )
        )

    assert reaction_exc.value.status_code == 400
