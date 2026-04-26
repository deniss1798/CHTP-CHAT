import asyncio

import pytest
from fastapi import HTTPException

from app.application.messages.commands import send_text_message
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.user import User
from app.schemas.message_schema import MessageCreate


def _user(user_id: int, username: str) -> User:
    return User(
        id=user_id,
        username=username,
        email=f"{username}@example.com",
        password_hash="hash",
    )


def _seed_private_chat(db_session) -> User:
    alice = _user(1, "alice")
    bob = _user(2, "bob")
    db_session.add_all(
        [
            alice,
            bob,
            Chat(id=10, type="private", title="bob", created_by=1),
            ChatMember(id=1001, chat_id=10, user_id=1, role="owner"),
            ChatMember(id=1002, chat_id=10, user_id=2, role="member"),
        ]
    )
    db_session.commit()
    return alice


def test_send_call_event_message_persists_call_type(db_session, monkeypatch) -> None:
    alice = _seed_private_chat(db_session)

    async def fake_notify(*args, **kwargs) -> None:
        return None

    monkeypatch.setattr("app.application.messages.commands._notify_new_message", fake_notify)

    response = asyncio.run(
        send_text_message(
            db_session,
            current_user=alice,
            payload=MessageCreate(
                chat_id=10,
                text="Вызов завершён. Длительность: 00:12",
                message_type="call_event",
            ),
        )
    )

    assert response.message_type == "call_event"
    assert response.text == "Вызов завершён. Длительность: 00:12"


def test_send_text_message_rejects_unknown_message_type(db_session) -> None:
    alice = _seed_private_chat(db_session)

    with pytest.raises(HTTPException) as exc_info:
        asyncio.run(
            send_text_message(
                db_session,
                current_user=alice,
                payload=MessageCreate(
                    chat_id=10,
                    text="unsupported",
                    message_type="system",
                ),
            )
        )

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail == "Unsupported message type"
