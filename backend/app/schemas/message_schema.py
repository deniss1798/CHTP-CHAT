from pydantic import BaseModel
from datetime import datetime


class MessageCreate(BaseModel):
    chat_id: int
    text: str


class MessageUpdate(BaseModel):
    text: str


class MessageResponse(BaseModel):
    id: int
    chat_id: int
    sender_id: int
    text: str
    created_at: datetime
    updated_at: datetime
    is_updated: bool