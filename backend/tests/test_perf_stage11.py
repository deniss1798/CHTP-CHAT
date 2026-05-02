from datetime import datetime, timedelta, timezone

from app.core.security import hash_password
from app.models.call import Call
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.device_token import DeviceToken
from app.models.user import User
from tests.api_helpers import auth_header, register_user
from tests.test_performance_queries import QueryCounter


def test_user_search_returns_paginated_page(
    api_client, db_session, monkeypatch
) -> None:
    token = register_user(
        api_client, monkeypatch, "alice", "alice_search@example.com"
    )
    db_session.add(
        User(
            id=99,
            username="bobbins",
            email="bob@example.com",
            password_hash=hash_password("Password123!"),
        )
    )
    db_session.commit()

    r = api_client.get(
        "/users/?q=bo&limit=5",
        headers=auth_header(token),
    )
    assert r.status_code == 200
    data = r.json()
    assert "users" in data
    assert "has_more" in data
    assert "next_cursor" in data
    assert len(data["users"]) == 1
    assert data["users"][0]["username"] == "bobbins"


def test_devices_list_paginated(api_client, db_session, monkeypatch) -> None:
    token = register_user(
        api_client, monkeypatch, "devu", "devu@example.com"
    )
    me = (
        db_session.query(User)
        .filter(User.email == "devu@example.com")
        .first()
    )
    assert me is not None
    base = datetime(2026, 1, 1, 12, 0, 0, tzinfo=timezone.utc)
    for i in range(3):
        db_session.add(
            DeviceToken(
                id=1000 + i,
                user_id=me.id,
                token=f"tok-{i}-" + "x" * 24,
                platform="android",
                device_name=f"d{i}",
                is_active=True,
                updated_at=base + timedelta(seconds=i),
            )
        )
    db_session.commit()

    r1 = api_client.get(
        "/devices?limit=2",
        headers=auth_header(token),
    )
    assert r1.status_code == 200
    p1 = r1.json()
    assert p1["has_more"] is True
    assert len(p1["devices"]) == 2
    assert p1["next_cursor"]

    r2 = api_client.get(
        f"/devices?limit=2&cursor={p1['next_cursor']}",
        headers=auth_header(token),
    )
    assert r2.status_code == 200
    p2 = r2.json()
    assert p2["has_more"] is False
    assert len(p2["devices"]) == 1


def test_calls_list_for_member(api_client, db_session, monkeypatch) -> None:
    token = register_user(
        api_client, monkeypatch, "caller", "caller@example.com"
    )
    u = (
        db_session.query(User)
        .filter(User.email == "caller@example.com")
        .first()
    )
    ch = Chat(id=500, type="group", created_by=u.id, title="G")
    db_session.add(ch)
    db_session.add(
        ChatMember(
            id=5001, chat_id=ch.id, user_id=u.id, role="owner"
        )
    )
    t0 = datetime(2026, 4, 1, 12, 0, 0, tzinfo=timezone.utc)
    db_session.add(
        Call(
            id=7001,
            chat_id=ch.id,
            initiator_id=u.id,
            type="voice",
            status="ended",
            started_at=t0,
            client_call_id="client-call-1",
        )
    )
    db_session.commit()

    r = api_client.get(
        "/calls?chat_id=500",
        headers=auth_header(token),
    )
    assert r.status_code == 200
    data = r.json()
    assert data["has_more"] is False
    assert len(data["calls"]) == 1
    assert data["calls"][0]["id"] == 7001


def test_get_chats_query_count_bounded(
    db_session, api_client, monkeypatch
) -> None:
    token = register_user(
        api_client, monkeypatch, "alperf", "al_perf_chats@example.com"
    )
    u = (
        db_session.query(User)
        .filter(User.email == "al_perf_chats@example.com")
        .first()
    )
    for i in range(1, 5):
        ch = Chat(id=6000 + i, type="private", created_by=u.id)
        db_session.add(ch)
        db_session.add_all(
            [
                ChatMember(
                    id=8000 + i * 2,
                    chat_id=ch.id,
                    user_id=u.id,
                    last_read_message_id=None,
                ),
                ChatMember(
                    id=8000 + i * 2 + 1,
                    chat_id=ch.id,
                    user_id=7000 + i,
                    last_read_message_id=None,
                ),
            ]
        )
        db_session.add(
            User(
                id=7000 + i,
                username=f"u{i}perf",
                email=f"u{i}p@e.com",
                password_hash=hash_password("Passw1!"),
            )
        )
    db_session.commit()

    with QueryCounter(db_session.bind) as counter:
        r = api_client.get(
            "/chats/?limit=20",
            headers=auth_header(token),
        )
    assert r.status_code == 200
    assert counter.count <= 8


def test_device_token_model_has_list_index() -> None:
    from app.models.device_token import DeviceToken

    assert "ix_device_tokens_user_updated_id" in {
        i.name for i in DeviceToken.__table__.indexes
    }
