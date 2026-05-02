import pytest
from starlette.websockets import WebSocketDisconnect

from tests.api_helpers import auth_header, register_user


def _me(api_client, token: str) -> dict:
    response = api_client.get("/users/me", headers=auth_header(token))
    assert response.status_code == 200
    return response.json()


def _ws_token(api_client, token: str) -> str:
    response = api_client.post("/auth/ws-token", headers=auth_header(token))
    assert response.status_code == 200
    return response.json()["ws_token"]


def test_inbox_websocket_accepts_ws_token_and_pongs(api_client, monkeypatch) -> None:
    token = register_user(api_client, monkeypatch, "alice", "alice@example.com")
    ws_token = _ws_token(api_client, token)

    with api_client.websocket_connect(f"/ws/inbox?token={ws_token}") as websocket:
        websocket.send_json({"type": "ping"})
        assert websocket.receive_json() == {"type": "pong"}


def test_chat_websocket_accepts_member_ws_token(
    api_client,
    db_session,
    monkeypatch,
) -> None:
    alice = register_user(api_client, monkeypatch, "alice", "alice@example.com")
    bob = register_user(api_client, monkeypatch, "bob", "bob@example.com")
    bob_id = _me(api_client, bob)["id"]
    chat = api_client.post(
        "/chats/",
        json={"type": "private", "member_ids": [bob_id]},
        headers=auth_header(alice),
    )
    assert chat.status_code == 200
    chat_id = chat.json()["id"]
    ws_token = _ws_token(api_client, alice)

    monkeypatch.setattr("app.api.ws_router.SessionLocal", lambda: db_session)

    with api_client.websocket_connect(f"/ws/chat/{chat_id}?token={ws_token}") as websocket:
        websocket.send_json({"type": "typing", "typing": True})


def test_chat_websocket_rejects_non_member_ws_token(
    api_client,
    db_session,
    monkeypatch,
) -> None:
    alice = register_user(api_client, monkeypatch, "alice", "alice@example.com")
    bob = register_user(api_client, monkeypatch, "bob", "bob@example.com")
    charlie = register_user(api_client, monkeypatch, "charlie", "charlie@example.com")
    bob_id = _me(api_client, bob)["id"]
    chat = api_client.post(
        "/chats/",
        json={"type": "private", "member_ids": [bob_id]},
        headers=auth_header(alice),
    )
    chat_id = chat.json()["id"]
    ws_token = _ws_token(api_client, charlie)

    monkeypatch.setattr("app.api.ws_router.SessionLocal", lambda: db_session)

    with pytest.raises(WebSocketDisconnect) as exc_info:
        with api_client.websocket_connect(f"/ws/chat/{chat_id}?token={ws_token}"):
            pass

    assert exc_info.value.code == 1008
