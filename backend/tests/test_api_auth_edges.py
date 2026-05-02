from datetime import timedelta

from tests.api_helpers import auth_header, register_user, seed_pending_registration


def test_request_email_code_rejects_existing_email(api_client, monkeypatch) -> None:
    register_user(api_client, monkeypatch, "alice", "alice@example.com")

    response = api_client.post(
        "/auth/request-email-code",
        json={
            "username": "alice2",
            "email": "alice@example.com",
            "password": "Password123!",
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "User already exists"


def test_verify_email_code_rejects_wrong_code(api_client, db_session) -> None:
    seed_pending_registration(db_session, code="123456")

    response = api_client.post(
        "/auth/verify-email-code",
        json={"email": "pending@example.com", "code": "000000"},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Invalid verification code"


def test_verify_email_code_rejects_expired_code(api_client, db_session) -> None:
    seed_pending_registration(
        db_session,
        code="123456",
        expires_delta=timedelta(minutes=-1),
    )

    response = api_client.post(
        "/auth/verify-email-code",
        json={"email": "pending@example.com", "code": "123456"},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Verification code expired"


def test_verify_email_code_rejects_too_many_attempts(api_client, db_session) -> None:
    seed_pending_registration(db_session, code="123456", attempts_count=5)

    response = api_client.post(
        "/auth/verify-email-code",
        json={"email": "pending@example.com", "code": "123456"},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Too many invalid attempts"


def test_login_rejects_wrong_password(api_client, monkeypatch) -> None:
    register_user(api_client, monkeypatch, "alice", "alice@example.com")

    response = api_client.post(
        "/auth/login",
        json={"email": "alice@example.com", "password": "WrongPassword123!"},
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid email or password"


def test_users_me_requires_and_accepts_token(api_client, monkeypatch) -> None:
    token = register_user(api_client, monkeypatch, "alice", "alice@example.com")

    unauthorized = api_client.get("/users/me")
    assert unauthorized.status_code == 401

    authorized = api_client.get("/users/me", headers=auth_header(token))
    assert authorized.status_code == 200
    assert authorized.json()["email"] == "alice@example.com"
