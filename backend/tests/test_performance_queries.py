from datetime import datetime, timedelta

from sqlalchemy import event

from app.application.chats.chat_listing import list_my_chats_page
from app.application.messages.queries import list_chat_messages
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.device_token import DeviceToken
from app.models.message import Message
from app.models.user import User


class QueryCounter:
    def __init__(self, bind) -> None:
        self.count = 0
        self._bind = bind

    def __enter__(self):
        event.listen(self._bind, "before_cursor_execute", self._increment)
        return self

    def __exit__(self, exc_type, exc, tb):
        event.remove(self._bind, "before_cursor_execute", self._increment)

    def _increment(self, *args, **kwargs) -> None:
        self.count += 1


def _user(user_id: int, username: str) -> User:
    return User(
        id=user_id,
        username=username,
        email=f"{username}@example.com",
        password_hash="hash",
    )


def test_chat_list_query_count_does_not_scale_per_chat(db_session) -> None:
    alice = _user(1, "alice")
    users = [alice, *[_user(i, f"user{i}") for i in range(2, 8)]]
    db_session.add_all(users)
    now = datetime.utcnow()

    for idx in range(1, 7):
        chat = Chat(id=idx, type="private", created_by=alice.id)
        db_session.add(chat)
        db_session.add_all(
            [
                ChatMember(
                    chat_id=idx,
                    user_id=alice.id,
                    last_read_message_id=None,
                ),
                ChatMember(chat_id=idx, user_id=idx + 1),
            ]
        )
        db_session.add(
            Message(
                id=idx,
                chat_id=idx,
                sender_id=idx + 1,
                text=f"hello {idx}",
                message_type="text",
                created_at=now + timedelta(seconds=idx),
            )
        )

    db_session.commit()

    with QueryCounter(db_session.bind) as counter:
        page = list_my_chats_page(db_session, alice, limit=6, cursor=None)

    assert len(page.chats) == 6
    assert counter.count <= 6


def test_message_list_batches_delivery_status(db_session) -> None:
    alice = _user(1, "alice")
    bob = _user(2, "bob")
    chat = Chat(id=1, type="private", created_by=alice.id)
    db_session.add_all(
        [
            alice,
            bob,
            chat,
            ChatMember(chat_id=1, user_id=alice.id, last_read_message_id=3),
            ChatMember(chat_id=1, user_id=bob.id, last_read_message_id=2),
        ]
    )
    now = datetime.utcnow()
    for idx in range(1, 6):
        db_session.add(
            Message(
                id=idx,
                chat_id=1,
                sender_id=alice.id if idx % 2 else bob.id,
                text=f"m{idx}",
                message_type="text",
                media_key="private/key" if idx == 1 else None,
                created_at=now + timedelta(seconds=idx),
            )
        )
    db_session.commit()

    with QueryCounter(db_session.bind) as counter:
        page = list_chat_messages(
            db_session,
            current_user=alice,
            chat_id=1,
            limit=5,
        )

    assert [m.id for m in page.messages] == [1, 2, 3, 4, 5]
    assert page.messages[0].media_key is None
    assert counter.count <= 6


def test_performance_indexes_are_declared() -> None:
    message_indexes = {index.name for index in Message.__table__.indexes}
    member_indexes = {index.name for index in ChatMember.__table__.indexes}
    device_indexes = {index.name for index in DeviceToken.__table__.indexes}

    assert "ix_messages_chat_id_id" in message_indexes
    assert "ix_messages_chat_id_created_at_id" in message_indexes
    assert "ix_chat_members_user_chat" in member_indexes
    assert "ix_device_tokens_user_updated_id" in device_indexes
