from datetime import datetime

from pydantic import BaseModel, Field


class MessageCreate(BaseModel):
    chat_id: int
    text: str = Field(..., min_length=1, max_length=4000)


class MessageUpdate(BaseModel):
    text: str = Field(..., min_length=1, max_length=4000)


class MessageResponse(BaseModel):
    id: int
    chat_id: int
    sender_id: int
    text: str
    created_at: datetime
    updated_at: datetime
    is_updated: bool

    class Config:
        from_attributes = True