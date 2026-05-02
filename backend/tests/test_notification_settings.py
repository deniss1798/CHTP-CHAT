from app.api.notification_settings_router import (
    get_notification_settings,
    update_notification_settings,
)
from app.core.push_service import send_chat_message_push
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.device_token import DeviceToken
from app.models.notification_setting import NotificationSetting
from app.models.user import User
from app.schemas.notification_setting import NotificationSettingUpdate


def _user(user_id: int, username: str) -> User:
    return User(
        id=user_id,
        username=username,
        email=f"{username}@example.com",
        password_hash="hash",
    )


def test_notification_settings_default_and_update(db_session) -> None:
    alice = _user(1, "alice")
    db_session.add(alice)
    db_session.commit()

    settings = get_notification_settings(db=db_session, current_user=alice)
    assert settings.notifications_enabled is True

    updated = update_notification_settings(
        NotificationSettingUpdate(notifications_enabled=False),
        db=db_session,
        current_user=alice,
    )

    assert updated.notifications_enabled is False


def test_push_skips_users_with_disabled_notifications(db_session, monkeypatch) -> None:
    alice = _user(1, "alice")
    bob = _user(2, "bob")
    db_session.add_all(
        [
            alice,
            bob,
            Chat(id=10, type="private", title="bob", created_by=1),
            ChatMember(id=1001, chat_id=10, user_id=1, role="owner"),
            ChatMember(id=1002, chat_id=10, user_id=2, role="member"),
            DeviceToken(
                id=201,
                user_id=2,
                token="b" * 32,
                platform="android",
                device_name="Pixel",
                is_active=True,
            ),
            NotificationSetting(user_id=2, notifications_enabled=False),
        ]
    )
    db_session.commit()

    sent: list[object] = []
    monkeypatch.setattr("app.core.push_service.get_firebase_app", lambda: object())
    monkeypatch.setattr("app.core.push_service.messaging.send", lambda msg: sent.append(msg))

    send_chat_message_push(
        db_session,
        sender_name="alice",
        chat_id=10,
        recipient_user_ids=[2],
        message_text="hello",
    )

    assert sent == []
