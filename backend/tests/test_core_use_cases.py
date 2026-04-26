import asyncio

import pytest
from fastapi import HTTPException

from app.application.auth import auth_commands
from app.application.chats.chat_commands import create_chat
from app.application.chats.membership_commands import add_chat_member, remove_group_member
from app.application.messages.commands import (
    delete_message,
    forward_message,
    send_text_message,
    update_text_message,
)
from app.application.messages.queries import list_chat_messages
from app.application.messages.reaction_commands import (
    add_message_reaction,
    remove_message_reaction,
)
from app.core.security import hash_password
from app.models.user import User
from app.schemas.chat_schema import ChatCreate, ChatMemberAddRequest
from app.schemas.email_verification import RequestEmailCodeRequest, VerifyEmailCodeRequest
from app.schemas.message_schema import ForwardMessageRequest, MessageCreate, MessageUpdate
from app.schemas.user_schema import UserLogin


def _user(user_id: int, username: str, password: str = "Password123!") -> User:
    return User(
        id=user_id,
        username=username,
        email=f"{username}@example.com",
        password_hash=hash_password(password),
    )


def _seed_users(db_session) -> tuple[User, User, User]:
    alice = _user(1, "alice")
    bob = _user(2, "bob")
    charlie = _user(3, "charlie")
    db_session.add_all([alice, bob, charlie])
    db_session.commit()
    return alice, bob, charlie


@pytest.fixture()
def no_realtime(monkeypatch):
    async def noop(*args, **kwargs) -> None:
        return None

    monkeypatch.setattr("app.application.messages.commands._notify_new_message", noop)
    monkeypatch.setattr("app.application.messages.commands.publish_message_updated", noop)
    monkeypatch.setattr("app.application.messages.commands.publish_message_deleted", noop)
    monkeypatch.setattr(
        "app.application.messages.reaction_commands.publish_message_reactions_updated",
        noop,
    )


def test_auth_register_flow_and_login(db_session, monkeypatch) -> None:
    sent_codes: list[str] = []

    monkeypatch.setattr("app.application.auth.auth_commands.secrets.randbelow", lambda _: 123456)
    monkeypatch.setattr(
        "app.application.auth.auth_commands.send_verification_code_email",
        lambda email, code: sent_codes.append(code),
    )

    auth_commands.request_email_code(
        db_session,
        RequestEmailCodeRequest(
            username="newuser",
            email="newuser@example.com",
            password="Password123!",
        ),
    )

    assert sent_codes == ["223456"]

    token = auth_commands.verify_email_code(
        db_session,
        VerifyEmailCodeRequest(email="newuser@example.com", code="223456"),
    )
    assert token.access_token

    login = auth_commands.login_user(
        db_session,
        UserLogin(email="newuser@example.com", password="Password123!"),
    )
    assert login.access_token


def test_create_group_add_member_and_remove_member(db_session) -> None:
    alice, bob, charlie = _seed_users(db_session)

    group = create_chat(
        db_session,
        alice,
        ChatCreate(type="group", title="Team", member_ids=[bob.id]),
    )

    added = add_chat_member(
        db_session,
        chat_id=group.id,
        current_user=alice,
        payload=ChatMemberAddRequest(user_id=charlie.id),
    )
    assert added.id == charlie.id
    assert added.role == "member"

    remove_group_member(
        db_session,
        chat_id=group.id,
        member_user_id=charlie.id,
        current_user=alice,
    )

    with pytest.raises(HTTPException) as exc_info:
        list_chat_messages(db_session, current_user=charlie, chat_id=group.id)
    assert exc_info.value.status_code == 403


def test_message_send_edit_delete_forward_reply_and_reactions(db_session, no_realtime) -> None:
    alice, bob, _ = _seed_users(db_session)
    private_chat = create_chat(
        db_session,
        alice,
        ChatCreate(type="private", member_ids=[bob.id]),
    )
    group_chat = create_chat(
        db_session,
        alice,
        ChatCreate(type="group", title="Forward target", member_ids=[bob.id]),
    )

    first = asyncio.run(
        send_text_message(
            db_session,
            current_user=alice,
            payload=MessageCreate(chat_id=private_chat.id, text="hello"),
        )
    )
    assert first.text == "hello"

    edited = asyncio.run(
        update_text_message(
            db_session,
            current_user=alice,
            message_id=first.id,
            payload=MessageUpdate(text="hello edited"),
        )
    )
    assert edited.text == "hello edited"
    assert edited.is_updated is True

    reply = asyncio.run(
        send_text_message(
            db_session,
            current_user=bob,
            payload=MessageCreate(
                chat_id=private_chat.id,
                text="reply",
                reply_to_message_id=first.id,
            ),
        )
    )
    assert reply.reply_to_message_id == first.id
    assert reply.reply_to is not None

    reacted = asyncio.run(
        add_message_reaction(
            db_session,
            current_user=bob,
            message_id=first.id,
            emoji="👍",
        )
    )
    assert reacted.reactions[0].emoji == "👍"

    unreacted = asyncio.run(
        remove_message_reaction(
            db_session,
            current_user=bob,
            message_id=first.id,
            emoji="👍",
        )
    )
    assert unreacted.reactions == []

    forwarded = asyncio.run(
        forward_message(
            db_session,
            current_user=alice,
            payload=ForwardMessageRequest(
                target_chat_id=group_chat.id,
                source_message_id=first.id,
            ),
        )
    )
    assert forwarded.forwarded_from_user_id == alice.id
    assert forwarded.chat_id == group_chat.id

    deleted = asyncio.run(
        delete_message(db_session, current_user=alice, message_id=first.id)
    )
    assert deleted == {"detail": "Message deleted"}


def test_foreign_user_cannot_read_or_send_chat(db_session, no_realtime) -> None:
    alice, bob, charlie = _seed_users(db_session)
    private_chat = create_chat(
        db_session,
        alice,
        ChatCreate(type="private", member_ids=[bob.id]),
    )

    with pytest.raises(HTTPException) as read_exc:
        list_chat_messages(db_session, current_user=charlie, chat_id=private_chat.id)
    assert read_exc.value.status_code == 403

    with pytest.raises(HTTPException) as send_exc:
        asyncio.run(
            send_text_message(
                db_session,
                current_user=charlie,
                payload=MessageCreate(chat_id=private_chat.id, text="nope"),
            )
        )
    assert send_exc.value.status_code == 403
