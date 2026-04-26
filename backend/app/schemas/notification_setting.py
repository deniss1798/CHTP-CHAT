from datetime import datetime

from pydantic import BaseModel


class NotificationSettingUpdate(BaseModel):
    notifications_enabled: bool


class NotificationSettingResponse(BaseModel):
    notifications_enabled: bool
    created_at: datetime | None = None
    updated_at: datetime | None = None

    class Config:
        from_attributes = True
