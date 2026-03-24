from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import SessionLocal
from app.models.device_token import DeviceToken
from app.models.user import User
from app.schemas.device_token import DeviceTokenRegister

router = APIRouter(prefix="/devices", tags=["devices"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/register")
def register_device(
    payload: DeviceTokenRegister,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    existing = db.query(DeviceToken).filter(DeviceToken.token == payload.token).first()

    if existing:
        existing.user_id = current_user.id
        existing.platform = payload.platform
        existing.device_name = payload.device_name
        existing.is_active = True
        db.commit()
        db.refresh(existing)
        return {
            "message": "device token updated",
            "device_token_id": existing.id,
        }

    item = DeviceToken(
        user_id=current_user.id,
        token=payload.token,
        platform=payload.platform,
        device_name=payload.device_name,
        is_active=True,
    )
    db.add(item)
    db.commit()
    db.refresh(item)

    return {
        "message": "device token registered",
        "device_token_id": item.id,
    }