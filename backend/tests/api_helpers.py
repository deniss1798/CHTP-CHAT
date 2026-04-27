from datetime import datetime, timedelta, timezone

from app.core.security import hash_verification_code
from app.models.pending_registration import PendingRegistration


def auth_header(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def register_user(api_client, monkeypatch, username: str, email: str) -> str:
    sent_codes: list[str] = []

    monkeypatch.setattr(
        "app.application.auth.auth_commands.secrets.randbelow",
        lambda _: 123456,
    )
    monkeypatch.setattr(
        "app.application.auth.auth_commands.send_verification_code_email",
        lambda _email, code: sent_codes.append(code),
    )

    response = api_client.post(
        "/auth/request-email-code",
        json={
            "username": username,
            "email": email,
            "password": "Password123!",
        },
    )
    assert response.status_code == 200
    assert sent_codes[-1] == "223456"

    response = api_client.post(
        "/auth/verify-email-code",
        json={"email": email, "code": "223456"},
    )
    assert response.status_code == 200
    return response.json()["access_token"]


def seed_pending_registration(
    db_session,
    *,
    username: str = "pending",
    email: str = "pending@example.com",
    code: str = "123456",
    expires_delta: timedelta = timedelta(minutes=10),
    attempts_count: int = 0,
) -> PendingRegistration:
    pending = PendingRegistration(
        username=username,
        email=email,
        password_hash="hashed-password",
        verification_code=hash_verification_code(code),
        expires_at=datetime.now(timezone.utc) + expires_delta,
        attempts_count=attempts_count,
    )
    db_session.add(pending)
    db_session.commit()
    return pending
