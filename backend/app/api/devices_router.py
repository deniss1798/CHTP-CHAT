from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.device_token import DeviceToken
from app.models.user import User
from app.schemas.device_token import DeviceTokenRegister, DeviceTokenResponse

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


@router.get("", response_model=list[DeviceTokenResponse])
def list_my_devices(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return (
        db.query(DeviceToken)
        .filter(DeviceToken.user_id == current_user.id)
        .order_by(DeviceToken.updated_at.desc(), DeviceToken.id.desc())
        .all()
    )


@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
def revoke_my_device(
    device_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    row = (
        db.query(DeviceToken)
        .filter(
            DeviceToken.id == device_id,
            DeviceToken.user_id == current_user.id,
        )
        .first()
    )
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )

    row.is_active = False
    db.add(row)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)