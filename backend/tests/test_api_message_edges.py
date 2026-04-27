from tests.api_helpers import auth_header, register_user


def _me(api_client, token: str) -> dict:
    response = api_client.get("/users/me", headers=auth_header(token))
    assert response.status_code == 200
    return response.json()


def _private_chat(api_client, owner_token: str, member_id: int) -> int:
    response = api_client.post(
        "/chats/",
        json={"type": "private", "member_ids": [member_id]},
        headers=auth_header(owner_token),
    )
    assert response.status_code == 200
    return response.json()["id"]


def _send_text(api_client, token: str, chat_id: int, text: str, reply_to: int | None = None) -> dict:
    response = api_client.post(
        "/messages/",
        json={
            "chat_id": chat_id,
            "text": text,
            **({"reply_to_message_id": reply_to} if reply_to is not None else {}),
        },
        headers=auth_header(token),
    )
    assert response.status_code == 200
    return response.json()


def test_reply_read_state_and_pagination(api_client, monkeypatch) -> None:
    alice = register_user(api_client, monkeypatch, "alice", "alice@example.com")
    bob = register_user(api_client, monkeypatch, "bob", "bob@example.com")
    bob_id = _me(api_client, bob)["id"]
    chat_id = _private_chat(api_client, alice, bob_id)

    first = _send_text(api_client, alice, chat_id, "m-1")
    reply = _send_text(api_client, bob, chat_id, "reply", reply_to=first["id"])
    assert reply["reply_to_message_id"] == first["id"]
    assert reply["reply_to"]["id"] == first["id"]

    for i in range(2, 8):
        _send_text(api_client, alice, chat_id, f"m-{i}")

    page = api_client.get(
        f"/messages/chat/{chat_id}",
        params={"limit": 3},
        headers=auth_header(alice),
    )
    assert page.status_code == 200
    assert len(page.json()["messages"]) == 3
    assert page.json()["has_more"] is True

    read = api_client.post(
        f"/chats/{chat_id}/read",
        json={"message_id": reply["id"]},
        headers=auth_header(bob),
    )
    assert read.status_code == 200

    state = api_client.get(f"/chats/{chat_id}/read-state", headers=auth_header(alice))
    assert state.status_code == 200
    by_user = {row["user_id"]: row["last_read_message_id"] for row in state.json()}
    assert by_user[bob_id] == reply["id"]


def test_foreign_user_cannot_send_edit_or_delete(api_client, monkeypatch) -> None:
    alice = register_user(api_client, monkeypatch, "alice", "alice@example.com")
    bob = register_user(api_client, monkeypatch, "bob", "bob@example.com")
    charlie = register_user(api_client, monkeypatch, "charlie", "charlie@example.com")
    bob_id = _me(api_client, bob)["id"]
    chat_id = _private_chat(api_client, alice, bob_id)
    message = _send_text(api_client, alice, chat_id, "owner text")

    foreign_send = api_client.post(
        "/messages/",
        json={"chat_id": chat_id, "text": "no access"},
        headers=auth_header(charlie),
    )
    assert foreign_send.status_code == 403

    foreign_edit = api_client.patch(
        f"/messages/{message['id']}",
        json={"text": "hacked"},
        headers=auth_header(charlie),
    )
    assert foreign_edit.status_code == 403

    foreign_delete = api_client.delete(
        f"/messages/{message['id']}",
        headers=auth_header(charlie),
    )
    assert foreign_delete.status_code == 403


def test_cannot_react_to_deleted_message(api_client, monkeypatch) -> None:
    alice = register_user(api_client, monkeypatch, "alice", "alice@example.com")
    bob = register_user(api_client, monkeypatch, "bob", "bob@example.com")
    bob_id = _me(api_client, bob)["id"]
    chat_id = _private_chat(api_client, alice, bob_id)
    message = _send_text(api_client, alice, chat_id, "delete me")

    deleted = api_client.delete(
        f"/messages/{message['id']}",
        headers=auth_header(alice),
    )
    assert deleted.status_code == 200

    reaction = api_client.post(
        f"/messages/{message['id']}/reactions",
        json={"emoji": "👍"},
        headers=auth_header(bob),
    )
    assert reaction.status_code == 400
    assert reaction.json()["detail"] == "Deleted messages cannot have reactions"


def test_reaction_add_and_remove(api_client, monkeypatch) -> None:
    alice = register_user(api_client, monkeypatch, "alice", "alice@example.com")
    bob = register_user(api_client, monkeypatch, "bob", "bob@example.com")
    bob_id = _me(api_client, bob)["id"]
    chat_id = _private_chat(api_client, alice, bob_id)
    message = _send_text(api_client, alice, chat_id, "react")

    added = api_client.post(
        f"/messages/{message['id']}/reactions",
        json={"emoji": "🔥"},
        headers=auth_header(bob),
    )
    assert added.status_code == 200
    assert added.json()["reactions"][0]["emoji"] == "🔥"

    removed = api_client.delete(
        f"/messages/{message['id']}/reactions",
        params={"emoji": "🔥"},
        headers=auth_header(bob),
    )
    assert removed.status_code == 200
    assert removed.json()["reactions"] == []
