from app.models.user import User
from app.core.security import hash_password
from tests.api_helpers import auth_header as _auth_header
from tests.api_helpers import register_user as _register


def test_auth_and_users_me_endpoints(api_client, monkeypatch) -> None:
    token = _register(api_client, monkeypatch, "alice", "alice@example.com")

    login = api_client.post(
        "/auth/login",
        json={"email": "alice@example.com", "password": "Password123!"},
    )
    assert login.status_code == 200
    assert login.json()["access_token"]

    unauthorized = api_client.get("/users/me")
    assert unauthorized.status_code == 401

    me = api_client.get("/users/me", headers=_auth_header(token))
    assert me.status_code == 200
    assert me.json()["username"] == "alice"

    ws_token = api_client.post("/auth/ws-token", headers=_auth_header(token))
    assert ws_token.status_code == 200
    assert ws_token.json()["ws_token"]
    assert ws_token.json()["expires_in"] == 60


def test_auth_login_rate_limit(api_client, db_session) -> None:
    db_session.add(
        User(
            username="alice",
            email="alice@example.com",
            password_hash=hash_password("Password123!"),
        )
    )
    db_session.commit()

    for _ in range(5):
        response = api_client.post(
            "/auth/login",
            json={"email": "alice@example.com", "password": "wrong-password"},
        )
        assert response.status_code == 401

    limited = api_client.post(
        "/auth/login",
        json={"email": "alice@example.com", "password": "wrong-password"},
    )
    assert limited.status_code == 429


def test_chat_and_message_endpoints(api_client, monkeypatch) -> None:
    alice_token = _register(api_client, monkeypatch, "alice", "alice@example.com")
    bob_token = _register(api_client, monkeypatch, "bob", "bob@example.com")

    bob_me = api_client.get("/users/me", headers=_auth_header(bob_token)).json()
    bob_id = bob_me["id"]

    created_chat = api_client.post(
        "/chats/",
        json={"type": "private", "member_ids": [bob_id]},
        headers=_auth_header(alice_token),
    )
    assert created_chat.status_code == 200
    chat_id = created_chat.json()["id"]

    chats = api_client.get("/chats/", headers=_auth_header(alice_token))
    assert chats.status_code == 200
    assert chats.json()["chats"][0]["id"] == chat_id

    detail = api_client.get(f"/chats/{chat_id}", headers=_auth_header(alice_token))
    assert detail.status_code == 200
    assert len(detail.json()["members"]) == 2

    sent = api_client.post(
        "/messages/",
        json={"chat_id": chat_id, "text": "hello"},
        headers=_auth_header(alice_token),
    )
    assert sent.status_code == 200
    message_id = sent.json()["id"]

    page = api_client.get(f"/messages/chat/{chat_id}", headers=_auth_header(alice_token))
    assert page.status_code == 200
    assert page.json()["messages"][0]["text"] == "hello"

    edited = api_client.patch(
        f"/messages/{message_id}",
        json={"text": "hello edited"},
        headers=_auth_header(alice_token),
    )
    assert edited.status_code == 200
    assert edited.json()["text"] == "hello edited"

    deleted = api_client.delete(
        f"/messages/{message_id}",
        headers=_auth_header(alice_token),
    )
    assert deleted.status_code == 200
    assert deleted.json() == {"detail": "Message deleted"}


def test_message_send_rate_limit(api_client, monkeypatch) -> None:
    alice_token = _register(api_client, monkeypatch, "alice", "alice@example.com")
    bob_token = _register(api_client, monkeypatch, "bob", "bob@example.com")
    bob_id = api_client.get("/users/me", headers=_auth_header(bob_token)).json()["id"]
    chat_id = api_client.post(
        "/chats/",
        json={"type": "private", "member_ids": [bob_id]},
        headers=_auth_header(alice_token),
    ).json()["id"]

    for i in range(60):
        response = api_client.post(
            "/messages/",
            json={"chat_id": chat_id, "text": f"m-{i}"},
            headers=_auth_header(alice_token),
        )
        assert response.status_code == 200

    limited = api_client.post(
        "/messages/",
        json={"chat_id": chat_id, "text": "too much"},
        headers=_auth_header(alice_token),
    )
    assert limited.status_code == 429
