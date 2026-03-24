from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.device_token import DeviceToken
from app.models.user import User
from app.schemas.device_token import DeviceTokenRegister

router = APIRouter(prefix="/devices", tags=["Devices"])


@router.post("/register-token")
def register_device_token(
    payload: DeviceTokenRegister,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    existing = (
        db.query(DeviceToken)
        .filter(DeviceToken.token == payload.token)
        .first()
    )

    if existing:
        existing.user_id = current_user.id
        existing.platform = payload.platform
        existing.device_name = payload.device_name
        existing.is_active = True
    else:
        db_token = DeviceToken(
            user_id=current_user.id,
            token=payload.token,
            platform=payload.platform,
            device_name=payload.device_name,
            is_active=True,
        )
        db.add(db_token)

    db.commit()
    return {"message": "Device token registered successfully"}