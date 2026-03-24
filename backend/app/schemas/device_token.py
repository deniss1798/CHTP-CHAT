from typing import Literal

from pydantic import BaseModel, Field


class DeviceTokenRegister(BaseModel):
    token: str = Field(..., min_length=20, max_length=512)
    platform: Literal["android", "ios"] = "android"
    device_name: str | None = Field(default=None, max_length=100)