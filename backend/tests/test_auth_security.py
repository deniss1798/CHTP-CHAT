from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException

from app.application.auth.auth_commands import request_email_code, verify_email_code
from app.core.log_redaction import redact_value
from app.core.rate_limit import (
    MEDIA_UPLOAD_RULE,
    WS_CONNECT_RULE,
    InMemoryRateLimiter,
)
from app.core.security import hash_verification_code, verify_verification_code
from app.infrastructure.storage.s3_storage import S3StorageService
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


def test_media_and_ws_rate_limit_rules_block_abuse() -> None:
    limiter = InMemoryRateLimiter()

    for _ in range(MEDIA_UPLOAD_RULE.max_attempts):
        limiter.check("user-1", MEDIA_UPLOAD_RULE)

    with pytest.raises(HTTPException) as media_exc:
        limiter.check("user-1", MEDIA_UPLOAD_RULE)

    assert media_exc.value.status_code == 429

    for _ in range(WS_CONNECT_RULE.max_attempts):
        limiter.check("ip:user-1", WS_CONNECT_RULE)

    with pytest.raises(HTTPException) as ws_exc:
        limiter.check("ip:user-1", WS_CONNECT_RULE)

    assert ws_exc.value.status_code == 429


def test_private_media_presigned_url_default_ttl_is_short() -> None:
    assert S3StorageService.generate_private_file_url.__kwdefaults__["expires_in"] == 900
