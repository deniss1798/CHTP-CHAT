from pydantic import BaseModel


class DeviceTokenRegister(BaseModel):
    token: str
    platform: str | None = "android"
    device_name: str | None = None