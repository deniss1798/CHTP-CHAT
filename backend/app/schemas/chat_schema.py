from pydantic import BaseModel
from typing import Literal
from pydantic import BaseModel
from typing import Optional


class UserShort(BaseModel):
    id: int
    username: str
    email: str


class ChatDetailResponse(BaseModel):
    id: int
    type: str
    title: Optional[str]
    created_by: int
    other_user: Optional[UserShort] = None

class ChatMemberResponse(BaseModel):
    id: int
    username: str
    email: str
    role: str


class ChatCreate(BaseModel):
    type: Literal["private", "group"]
    title: str | None = None
    member_ids: list[int]


class ChatResponse(BaseModel):
    id: int
    type: str
    title: str | None
    created_by: int | None