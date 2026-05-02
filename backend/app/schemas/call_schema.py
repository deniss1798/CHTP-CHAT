from datetime import datetime

from pydantic import BaseModel


class CallResponse(BaseModel):
    id: int
    chat_id: int
    initiator_id: int | None
    type: str
    status: str
    started_at: datetime
    accepted_at: datetime | None
    ended_at: datetime | None
    duration_seconds: int | None
    client_call_id: str | None = None

    class Config:
        from_attributes = True


class CallListPage(BaseModel):
    calls: list[CallResponse]
    has_more: bool
    next_cursor: str | None = None
