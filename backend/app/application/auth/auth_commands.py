import secrets
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.email_service import send_verification_code_email
from app.core.security import (
    create_access_token,
    hash_password,
    hash_verification_code,
    verify_password,
    verify_verification_code,
)
from app.models.pending_registration import PendingRegistration
from app.models.user import User
from app.schemas.email_verification import RequestEmailCodeRequest, VerifyEmailCodeRequest
from app.schemas.user_schema import TokenResponse, UserLogin


def request_email_code(db: Session, payload: RequestEmailCodeRequest) -> dict:
    existing_user = db.query(User).filter(
        (User.email == payload.email) | (User.username == payload.username)
    ).first()

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User already exists",
        )

    code = f"{secrets.randbelow(900000) + 100000}"
    code_hash = hash_verification_code(code)
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)

    try:
        password_hash_value = hash_password(payload.password)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    pending = (
        db.query(PendingRegistration)
        .filter(PendingRegistration.email == payload.email)
        .first()
    )

    if pending:
        pending.username = payload.username
        pending.password_hash = password_hash_value
        pending.verification_code = code_hash
        pending.expires_at = expires_at
        pending.attempts_count = 0
    else:
        pending = PendingRegistration(
            username=payload.username,
            email=payload.email,
            password_hash=password_hash_value,
            verification_code=code_hash,
            expires_at=expires_at,
            attempts_count=0,
        )
        db.add(pending)

    db.commit()

    try:
        send_verification_code_email(payload.email, code)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send verification email",
        )

    return {"message": "Verification code sent to email"}


def verify_email_code(db: Session, payload: VerifyEmailCodeRequest) -> TokenResponse:
    pending = (
        db.query(PendingRegistration)
        .filter(PendingRegistration.email == payload.email)
        .first()
    )

    if not pending:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Verification request not found",
        )

    now = datetime.now(timezone.utc)
    pending_expires_at = pending.expires_at

    if pending_expires_at.tzinfo is None:
        pending_expires_at = pending_expires_at.replace(tzinfo=timezone.utc)

    if pending_expires_at < now:
        db.delete(pending)
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Verification code expired",
        )

    if pending.attempts_count >= 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Too many invalid attempts",
        )

    if not verify_verification_code(payload.code, pending.verification_code):
        pending.attempts_count += 1
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification code",
        )

    existing_user_by_email = db.query(User).filter(User.email == pending.email).first()
    if existing_user_by_email:
        db.delete(pending)
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    existing_user_by_username = (
        db.query(User).filter(User.username == pending.username).first()
    )
    if existing_user_by_username:
        db.delete(pending)
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already taken",
        )

    new_user = User(
        username=pending.username,
        email=pending.email,
        password_hash=pending.password_hash,
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    db.delete(pending)
    db.commit()

    access_token = create_access_token({"sub": str(new_user.id)})
    return TokenResponse(access_token=access_token)


def login_user(db: Session, user_data: UserLogin) -> TokenResponse:
    user = db.query(User).filter(User.email == user_data.email).first()

    if not user or not verify_password(user_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    access_token = create_access_token({"sub": str(user.id)})
    return TokenResponse(access_token=access_token)
