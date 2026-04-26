from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException

from app.application.auth.auth_commands import request_email_code, verify_email_code
from app.core.log_redaction import redact_value
from app.core.security import hash_verification_code, verify_verification_code
from app.models.pending_registration import PendingRegistration
from app.schemas.email_verification import RequestEmailCodeRequest, VerifyEmailCodeRequest


def test_verification_code_hash_does_not_store_plain_code() -> None:
    code_hash = hash_verification_code("123456")

    assert code_hash != "123456"
    assert verify_verification_code("123456", code_hash)
    assert not verify_verification_code("000000", code_hash)


def test_request_email_code_stores_hash(db_session, monkeypatch) -> None:
    sent_codes: list[str] = []

    monkeypatch.setattr(
        "app.application.auth.auth_commands.send_verification_code_email",
        lambda email, code: sent_codes.append(code),
    )

    request_email_code(
        db_session,
        RequestEmailCodeRequest(
            username="alice",
            email="alice@example.com",
            password="secret123",
        ),
    )

    pending = db_session.query(PendingRegistration).one()
    assert len(sent_codes) == 1
    assert pending.verification_code != sent_codes[0]
    assert verify_verification_code(sent_codes[0], pending.verification_code)


def test_verify_email_code_increments_attempts_for_invalid_hash(db_session) -> None:
    pending = PendingRegistration(
        username="alice",
        email="alice@example.com",
        password_hash="password-hash",
        verification_code=hash_verification_code("123456"),
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=10),
        attempts_count=0,
    )
    db_session.add(pending)
    db_session.commit()

    with pytest.raises(HTTPException) as exc_info:
        verify_email_code(
            db_session,
            VerifyEmailCodeRequest(email="alice@example.com", code="000000"),
        )

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail == "Invalid verification code"
    db_session.refresh(pending)
    assert pending.attempts_count == 1


def test_redact_value_masks_sensitive_values() -> None:
    data = {
        "Authorization": "Bearer abc.def.ghi",
        "password": "secret123",
        "nested": {
            "access_token": "token-value",
            "url": "https://s3.example/private?X-Amz-Signature=abc",
        },
    }

    redacted = redact_value(data)

    assert redacted["Authorization"] == "***"
    assert redacted["password"] == "***"
    assert redacted["nested"]["access_token"] == "***"
    assert redacted["nested"]["url"] == "***"
