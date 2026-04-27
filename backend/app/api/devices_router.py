from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from app.application.devices.device_listing import list_my_devices_page
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.device_token import DeviceToken
from app.models.user import User
from app.schemas.device_token import DeviceListPage, DeviceTokenRegister, DeviceTokenResponse

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


@router.get("", response_model=DeviceListPage)
def list_my_devices(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    limit: int = Query(50, ge=1, le=200),
    cursor: str | None = Query(
        default=None,
        description="Курсор следующей страницы (next_cursor с предыдущего ответа)",
    ),
):
    return list_my_devices_page(
        db,
        current_user=current_user,
        limit=limit,
        cursor=cursor,
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


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
def revoke_all_my_devices(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    (
        db.query(DeviceToken)
        .filter(DeviceToken.user_id == current_user.id)
        .update({DeviceToken.is_active: False}, synchronize_session=False)
    )
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)