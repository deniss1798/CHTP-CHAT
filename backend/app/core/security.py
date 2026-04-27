import hmac
from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import get_settings

settings = get_settings()

pwd_context = CryptContext(
    schemes=["pbkdf2_sha256"],
    deprecated="auto",
)


def hash_password(password: str) -> str:
    if not password or len(password) < 6:
        raise ValueError("Password must be at least 6 characters long")
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def hash_verification_code(code: str) -> str:
    return pwd_context.hash(code)


def verify_verification_code(code: str, stored_code: str) -> bool:
    if stored_code.startswith("$pbkdf2-sha256$"):
        return pwd_context.verify(code, stored_code)

    # Backward compatibility for pending registrations created before code hashing.
    return hmac.compare_digest(stored_code, code)


def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.access_token_expire_minutes
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)


def create_ws_token(*, user_id: int, expires_seconds: int = 60) -> str:
    expire = datetime.now(timezone.utc) + timedelta(seconds=expires_seconds)
    payload = {
        "sub": str(user_id),
        "typ": "ws",
        "exp": expire,
    }
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)


def decode_access_token(token: str):
    try:
        payload = jwt.decode(
            token,
            settings.secret_key,
            algorithms=[settings.algorithm],
        )
        return payload
    except JWTError:
        return None


def decode_ws_or_access_token(token: str):
    payload = decode_access_token(token)
    if payload is None:
        return None
    token_type = payload.get("typ")
    if token_type not in (None, "access", "ws"):
        return None
    return payload