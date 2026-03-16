from pydantic import BaseModel
from typing import Literal


class ChatCreate(BaseModel):
    type: Literal["private", "group"]
    title: str | None = None
    member_ids: list[int]


class ChatResponse(BaseModel):
    id: int
    type: str
    title: str | None
    created_by: int | None