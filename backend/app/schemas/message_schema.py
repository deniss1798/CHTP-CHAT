from datetime import datetime

from pydantic import BaseModel, Field


class MessageCreate(BaseModel):
    chat_id: int
    text: str = Field(..., min_length=1)
    reply_to_message_id: int | None = None


class MessageReplyPreview(BaseModel):
    id: int
    sender_id: int
    text: str
    message_type: str
    media_url: str | None = None


class MessageUpdate(BaseModel):
    text: str = Field(..., min_length=1)


class MessageResponse(BaseModel):
    id: int
    chat_id: int
    sender_id: int

    text: str
    message_type: str

    media_key: str | None = None
    media_url: str | None = None
    media_mime_type: str | None = None
    media_size: int | None = None

    created_at: datetime
    updated_at: datetime | None = None
    is_updated: bool | None = False

    reply_to_message_id: int | None = None
    reply_to: MessageReplyPreview | None = None

    class Config:
        from_attributes = True