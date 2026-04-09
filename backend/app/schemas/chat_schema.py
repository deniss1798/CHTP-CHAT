from typing import Literal
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class UserShort(BaseModel):
    id: int
    username: str
    email: EmailStr
    avatar_url: str | None = None
    last_seen_at: datetime | None = None

    class Config:
        from_attributes = True


class ChatCreate(BaseModel):
    type: Literal["private", "group"]
    title: str | None = Field(default=None, max_length=255)
    member_ids: list[int] = Field(..., min_length=1, max_length=100)


class ChatUpdate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)


class ChatMemberAddRequest(BaseModel):
    user_id: int


class MarkChatReadRequest(BaseModel):
    message_id: int = Field(..., ge=1)


class MemberReadState(BaseModel):
    user_id: int
    last_read_message_id: int | None = None


class ChatResponse(BaseModel):
    id: int
    type: Literal["private", "group"]
    title: str | None
    avatar_url: str | None = None
    created_by: int | None

    last_message: str | None = None
    last_message_at: datetime | None = None
    last_message_sender_id: int | None = None
    last_message_id: int | None = None
    my_last_read_message_id: int | None = None
    unread_count: int = 0
    # Для личных чатов — last_seen собеседника (индикатор «в сети» в списке).
    peer_last_seen_at: datetime | None = None

    class Config:
        from_attributes = True


class ChatMemberResponse(BaseModel):
    id: int
    username: str
    email: EmailStr
    avatar_url: str | None = None
    role: str
    last_seen_at: datetime | None = None


class ChatDetailResponse(BaseModel):
    id: int
    type: Literal["private", "group"]
    title: str | None
    avatar_url: str | None = None
    created_by: int | None
    members: list[UserShort]