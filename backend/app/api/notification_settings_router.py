from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.notification_setting import NotificationSetting
from app.models.user import User
from app.schemas.notification_setting import (
    NotificationSettingResponse,
    NotificationSettingUpdate,
)

router = APIRouter(prefix="/notification-settings", tags=["Notification settings"])


def _get_or_create_settings(db: Session, user_id: int) -> NotificationSetting:
    settings = (
        db.query(NotificationSetting)
        .filter(NotificationSetting.user_id == user_id)
        .first()
    )
    if settings is not None:
        return settings

    settings = NotificationSetting(
        user_id=user_id,
        notifications_enabled=True,
    )
    db.add(settings)
    db.commit()
    db.refresh(settings)
    return settings


@router.get("", response_model=NotificationSettingResponse)
def get_notification_settings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _get_or_create_settings(db, current_user.id)


@router.put("", response_model=NotificationSettingResponse)
def update_notification_settings(
    payload: NotificationSettingUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    settings = _get_or_create_settings(db, current_user.id)
    settings.notifications_enabled = payload.notifications_enabled
    db.add(settings)
    db.commit()
    db.refresh(settings)
    return settings
