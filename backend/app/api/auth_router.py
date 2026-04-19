from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.application.auth import auth_commands
from app.db.database import get_db
from app.schemas.email_verification import (
    RequestEmailCodeRequest,
    VerifyEmailCodeRequest,
)
from app.schemas.user_schema import TokenResponse, UserLogin

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/request-email-code")
def request_email_code(
    payload: RequestEmailCodeRequest,
    db: Session = Depends(get_db),
):
    return auth_commands.request_email_code(db, payload)


@router.post("/verify-email-code", response_model=TokenResponse)
def verify_email_code(
    payload: VerifyEmailCodeRequest,
    db: Session = Depends(get_db),
):
    return auth_commands.verify_email_code(db, payload)


@router.post("/login", response_model=TokenResponse)
def login(
    user_data: UserLogin,
    db: Session = Depends(get_db),
):
    return auth_commands.login_user(db, user_data)
