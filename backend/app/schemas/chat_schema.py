from typing import Literal

from pydantic import BaseModel, EmailStr, Field


class UserShort(BaseModel):
    id: int
    username: str
    email: EmailStr
    avatar_url: str | None = None

    class Config:
        from_attributes = True


class ChatCreate(BaseModel):
    type: Literal["private", "group"]
    title: str | None = Field(default=None, max_length=255)
    member_ids: list[int] = Field(..., min_length=1, max_length=100)


class ChatMemberAddRequest(BaseModel):
    user_id: int


class ChatResponse(BaseModel):
    id: int
    type: Literal["private", "group"]
    title: str | None
    avatar_url: str | None = None
    created_by: int | None

    class Config:
        from_attributes = True


class ChatMemberResponse(BaseModel):
    id: int
    username: str
    email: EmailStr
    role: str


class ChatDetailResponse(BaseModel):
    id: int
    type: Literal["private", "group"]
    title: str | None
    avatar_url: str | None = None
    created_by: int | None
    members: list[UserShort]