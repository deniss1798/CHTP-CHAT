from app.application.chats.chat_commands import create_chat
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.user import User
from app.schemas.chat_schema import ChatCreate


def _user(user_id: int, username: str) -> User:
    return User(
        id=user_id,
        username=username,
        email=f"{username}@example.com",
        password_hash="hash",
    )


def test_create_private_chat_returns_existing_chat_for_same_pair(db_session) -> None:
    alice = _user(1, "alice")
    bob = _user(2, "bob")
    existing = Chat(id=100, type="private", title="bob", created_by=1)
    db_session.add_all(
        [
            alice,
            bob,
            existing,
            ChatMember(id=1001, chat_id=100, user_id=1, role="owner"),
            ChatMember(id=1002, chat_id=100, user_id=2, role="member"),
        ]
    )
    db_session.commit()

    response = create_chat(
        db_session,
        alice,
        ChatCreate(type="private", member_ids=[2]),
    )

    assert response.id == 100
    assert response.title == "bob"
    assert db_session.query(Chat).filter(Chat.type == "private").count() == 1


def test_create_private_chat_rejects_multiple_other_members(db_session) -> None:
    alice = _user(1, "alice")
    bob = _user(2, "bob")
    carol = _user(3, "carol")
    db_session.add_all([alice, bob, carol])
    db_session.commit()

    try:
        create_chat(
            db_session,
            alice,
            ChatCreate(type="private", member_ids=[2, 3]),
        )
    except Exception as exc:
        assert getattr(exc, "status_code") == 400
        assert "exactly one other participant" in getattr(exc, "detail")
    else:
        raise AssertionError("private chat creation should reject extra members")
