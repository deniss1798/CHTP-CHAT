from datetime import datetime, timedelta, timezone
import random

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.email_service import send_verification_code_email
from app.core.security import hash_password, verify_password, create_access_token
from app.db.database import get_db
from app.models.pending_registration import PendingRegistration
from app.models.user import User
from app.schemas.email_verification import (
    RequestEmailCodeRequest,
    VerifyEmailCodeRequest,
)
from app.schemas.user_schema import UserRegister, UserLogin, TokenResponse, UserResponse

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/request-email-code")
def request_email_code(
    payload: RequestEmailCodeRequest,
    db: Session = Depends(get_db),
):
    existing_user_by_email = db.query(User).filter(User.email == payload.email).first()
    if existing_user_by_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    existing_user_by_username = db.query(User).filter(User.username == payload.username).first()
    if existing_user_by_username:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already taken",
        )

    code = f"{random.randint(0, 999999):06d}"
    expires_at = datetime.utcnow() + timedelta(minutes=10)
    password_hash_value = hash_password(payload.password)

    pending = (
        db.query(PendingRegistration)
        .filter(PendingRegistration.email == payload.email)
        .first()
    )

    if pending:
        pending.username = payload.username
        pending.password_hash = password_hash_value
        pending.verification_code = code
        pending.expires_at = expires_at
        pending.attempts_count = 0
        db.commit()
    else:
        pending = PendingRegistration(
            username=payload.username,
            email=payload.email,
            password_hash=password_hash_value,
            verification_code=code,
            expires_at=expires_at,
            attempts_count=0,
        )
        db.add(pending)
        db.commit()

    send_verification_code_email(payload.email, code)

    return {"message": "Verification code sent"}


@router.post("/verify-email-code", response_model=TokenResponse)
def verify_email_code(
    payload: VerifyEmailCodeRequest,
    db: Session = Depends(get_db),
):
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

    if pending.expires_at < datetime.utcnow():
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

    if pending.verification_code != payload.code:
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

    existing_user_by_username = db.query(User).filter(User.username == pending.username).first()
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


@router.post("/register", response_model=UserResponse)
def register(user_data: UserRegister, db: Session = Depends(get_db)):
    existing_user_by_email = db.query(User).filter(User.email == user_data.email).first()
    if existing_user_by_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    existing_user_by_username = db.query(User).filter(User.username == user_data.username).first()
    if existing_user_by_username:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already taken",
        )

    new_user = User(
        username=user_data.username,
        email=user_data.email,
        password_hash=hash_password(user_data.password),
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return UserResponse(
        id=new_user.id,
        username=new_user.username,
        email=new_user.email,
    )


@router.post("/login", response_model=TokenResponse)
def login(user_data: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == user_data.email).first()

    if not user or not verify_password(user_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    access_token = create_access_token({"sub": str(user.id)})

    return TokenResponse(access_token=access_token)