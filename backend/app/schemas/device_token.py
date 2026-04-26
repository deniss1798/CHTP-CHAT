from typing import Literal
from datetime import datetime

from pydantic import BaseModel, Field


class DeviceTokenRegister(BaseModel):
    token: str = Field(..., min_length=20, max_length=512)
    platform: Literal["android", "ios"] = "android"
    device_name: str | None = Field(default=None, max_length=100)


class DeviceTokenResponse(BaseModel):
    id: int
    platform: str | None = None
    device_name: str | None = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True