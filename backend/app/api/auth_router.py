from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.application.auth import auth_commands
from app.core.dependencies import get_current_user
from app.core.rate_limit import (
    AUTH_LOGIN_RULE,
    AUTH_REQUEST_CODE_RULE,
    AUTH_VERIFY_CODE_RULE,
    client_ip,
    normalize_rate_key,
    rate_limiter,
)
from app.core.security import create_ws_token
from app.db.database import get_db
from app.schemas.email_verification import (
    RequestEmailCodeRequest,
    VerifyEmailCodeRequest,
)
from app.models.user import User
from app.schemas.user_schema import TokenResponse, UserLogin, WsTokenResponse

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/request-email-code")
def request_email_code(
    payload: RequestEmailCodeRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    rate_limiter.check(
        f"{client_ip(request)}:{normalize_rate_key(payload.email)}",
        AUTH_REQUEST_CODE_RULE,
    )
    return auth_commands.request_email_code(db, payload)


@router.post("/verify-email-code", response_model=TokenResponse)
def verify_email_code(
    payload: VerifyEmailCodeRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    rate_limiter.check(
        f"{client_ip(request)}:{normalize_rate_key(payload.email)}",
        AUTH_VERIFY_CODE_RULE,
    )
    return auth_commands.verify_email_code(db, payload)


@router.post("/login", response_model=TokenResponse)
def login(
    user_data: UserLogin,
    request: Request,
    db: Session = Depends(get_db),
):
    rate_limiter.check(
        f"{client_ip(request)}:{normalize_rate_key(user_data.email)}",
        AUTH_LOGIN_RULE,
    )
    return auth_commands.login_user(db, user_data)


@router.post("/ws-token", response_model=WsTokenResponse)
def issue_ws_token(
    current_user: User = Depends(get_current_user),
):
    expires_in = 60
    return WsTokenResponse(
        ws_token=create_ws_token(user_id=current_user.id, expires_seconds=expires_in),
        expires_in=expires_in,
    )
