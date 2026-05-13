from tests.api_helpers import auth_header, register_user


def _me(api_client, token: str) -> dict:
    response = api_client.get("/users/me", headers=auth_header(token))
    assert response.status_code == 200
    return response.json()


def test_private_chat_creation_is_idempotent(api_client, monkeypatch) -> None:
    alice = register_user(api_client, monkeypatch, "alice", "alice@example.com")
    bob = register_user(api_client, monkeypatch, "bob", "bob@example.com")
    bob_id = _me(api_client, bob)["id"]

    first = api_client.post(
        "/chats/",
        json={"type": "private", "member_ids": [bob_id]},
        headers=auth_header(alice),
    )
    second = api_client.post(
        "/chats/",
        json={"type": "private", "member_ids": [bob_id]},
        headers=auth_header(alice),
    )

    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["id"] == first.json()["id"]


def test_group_add_remove_rename_and_non_owner_remove_denied(
    api_client,
    monkeypatch,
) -> None:
    alice = register_user(api_client, monkeypatch, "alice", "alice@example.com")
    bob = register_user(api_client, monkeypatch, "bob", "bob@example.com")
    charlie = register_user(api_client, monkeypatch, "charlie", "charlie@example.com")
    bob_id = _me(api_client, bob)["id"]
    charlie_id = _me(api_client, charlie)["id"]

    created = api_client.post(
        "/chats/",
        json={"type": "group", "title": "Team", "member_ids": [bob_id]},
        headers=auth_header(alice),
    )
    assert created.status_code == 200
    chat_id = created.json()["id"]

    added = api_client.post(
        f"/chats/{chat_id}/members",
        json={"user_id": charlie_id},
        headers=auth_header(alice),
    )
    assert added.status_code == 200
    assert added.json()["id"] == charlie_id

    non_owner_remove = api_client.delete(
        f"/chats/{chat_id}/members/{charlie_id}",
        headers=auth_header(bob),
    )
    assert non_owner_remove.status_code == 403

    renamed = api_client.patch(
        f"/chats/{chat_id}",
        json={"title": "Team 2"},
        headers=auth_header(alice),
    )
    assert renamed.status_code == 200
    assert renamed.json()["title"] == "Team 2"

    members = api_client.get(f"/chats/{chat_id}/members", headers=auth_header(alice))
    assert members.status_code == 200
    assert {row["id"] for row in members.json()} == {1, bob_id, charlie_id}

    members_bob = api_client.get(
        f"/chats/{chat_id}/members",
        headers=auth_header(bob),
    )
    assert members_bob.status_code == 200
    assert {row["id"] for row in members_bob.json()} == {1, bob_id, charlie_id}

    removed = api_client.delete(
        f"/chats/{chat_id}/members/{charlie_id}",
        headers=auth_header(alice),
    )
    assert removed.status_code == 204

    after_remove = api_client.get(
        f"/chats/{chat_id}/members",
        headers=auth_header(alice),
    )
    assert {row["id"] for row in after_remove.json()} == {1, bob_id}


def test_group_leave_removes_current_user(api_client, monkeypatch) -> None:
    alice = register_user(api_client, monkeypatch, "alice", "alice@example.com")
    bob = register_user(api_client, monkeypatch, "bob", "bob@example.com")
    bob_id = _me(api_client, bob)["id"]

    created = api_client.post(
        "/chats/",
        json={"type": "group", "title": "Team", "member_ids": [bob_id]},
        headers=auth_header(alice),
    )
    chat_id = created.json()["id"]

    left = api_client.post(f"/chats/{chat_id}/leave", headers=auth_header(bob))
    assert left.status_code == 204

    denied = api_client.get(f"/chats/{chat_id}", headers=auth_header(bob))
    assert denied.status_code == 403
