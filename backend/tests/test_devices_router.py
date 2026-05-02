from fastapi import HTTPException

from app.api.devices_router import list_my_devices, revoke_all_my_devices, revoke_my_device
from app.models.device_token import DeviceToken
from app.models.user import User


def _user(user_id: int, username: str) -> User:
    return User(
        id=user_id,
        username=username,
        email=f"{username}@example.com",
        password_hash="hash",
    )


def test_list_my_devices_returns_only_current_user_tokens(db_session) -> None:
    alice = _user(1, "alice")
    bob = _user(2, "bob")
    db_session.add_all(
        [
            alice,
            bob,
            DeviceToken(
                id=101,
                user_id=1,
                token="a" * 32,
                platform="android",
                device_name="Pixel",
                is_active=True,
            ),
            DeviceToken(
                id=102,
                user_id=2,
                token="b" * 32,
                platform="ios",
                device_name="iPhone",
                is_active=True,
            ),
        ]
    )
    db_session.commit()

    page = list_my_devices(
        db=db_session, current_user=alice, limit=50, cursor=None
    )

    assert [device.id for device in page.devices] == [101]


def test_revoke_my_device_marks_token_inactive(db_session) -> None:
    alice = _user(1, "alice")
    token = DeviceToken(
        id=101,
        user_id=1,
        token="a" * 32,
        platform="android",
        device_name="Pixel",
        is_active=True,
    )
    db_session.add_all([alice, token])
    db_session.commit()

    revoke_my_device(device_id=101, db=db_session, current_user=alice)

    db_session.refresh(token)
    assert token.is_active is False


def test_revoke_my_device_rejects_other_user_token(db_session) -> None:
    alice = _user(1, "alice")
    bob = _user(2, "bob")
    db_session.add_all(
        [
            alice,
            bob,
            DeviceToken(
                id=102,
                user_id=2,
                token="b" * 32,
                platform="ios",
                device_name="iPhone",
                is_active=True,
            ),
        ]
    )
    db_session.commit()

    try:
        revoke_my_device(device_id=102, db=db_session, current_user=alice)
    except HTTPException as exc:
        assert exc.status_code == 404
    else:
        raise AssertionError("Expected HTTPException")


def test_revoke_all_my_devices_marks_only_current_user_tokens_inactive(db_session) -> None:
    alice = _user(1, "alice")
    bob = _user(2, "bob")
    alice_a = DeviceToken(
        id=101,
        user_id=1,
        token="a" * 32,
        platform="android",
        device_name="Pixel",
        is_active=True,
    )
    alice_b = DeviceToken(
        id=102,
        user_id=1,
        token="c" * 32,
        platform="ios",
        device_name="iPhone",
        is_active=True,
    )
    bob_token = DeviceToken(
        id=201,
        user_id=2,
        token="b" * 32,
        platform="android",
        device_name="Other",
        is_active=True,
    )
    db_session.add_all([alice, bob, alice_a, alice_b, bob_token])
    db_session.commit()

    revoke_all_my_devices(db=db_session, current_user=alice)

    db_session.refresh(alice_a)
    db_session.refresh(alice_b)
    db_session.refresh(bob_token)
    assert alice_a.is_active is False
    assert alice_b.is_active is False
    assert bob_token.is_active is True
