from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ForwardMessageRequest(BaseModel):
    target_chat_id: int = Field(..., ge=1)
    source_message_id: int = Field(..., ge=1)


class MessageCreate(BaseModel):
    chat_id: int
    text: str = Field(..., min_length=1)
    reply_to_message_id: int | None = None
    message_type: str = Field(default="text", max_length=32)
    client_message_id: str | None = Field(default=None, min_length=1, max_length=128)
    mention_user_ids: list[int] | None = Field(default=None, max_length=64)


class PollCreate(BaseModel):
    chat_id: int
    question: str = Field(..., min_length=1, max_length=255)
    options: list[str] = Field(..., min_length=2, max_length=10)
    allows_multiple: bool = False
    is_anonymous: bool = False
    client_message_id: str | None = Field(default=None, min_length=1, max_length=128)


class PollVoteRequest(BaseModel):
    option_ids: list[int] = Field(..., min_length=0, max_length=10)


class PollOptionResponse(BaseModel):
    id: int
    position: int
    text: str
    votes: int
    voted_by_me: bool
    voter_user_ids: list[int] = Field(default_factory=list)


class PollResponse(BaseModel):
    id: int
    message_id: int
    question: str
    allows_multiple: bool
    is_anonymous: bool
    is_closed: bool
    total_votes: int
    options: list[PollOptionResponse] = Field(default_factory=list)


class ReactionGroup(BaseModel):
    emoji: str
    count: int
    reacted_by_me: bool
    reactor_user_ids: list[int] = Field(
        default_factory=list,
        description="User ids who reacted with this emoji (for group tooltips).",
    )


class MessageReplyPreview(BaseModel):
    id: int
    sender_id: int
    text: str
    message_type: str
    media_url: str | None = None


class MessageUpdate(BaseModel):
    text: str = Field(..., min_length=1)


class MessageReactionBody(BaseModel):
    emoji: str = Field(..., min_length=1, max_length=32)


class MessageListPage(BaseModel):
    """Страница истории чата (курсор по id сообщения)."""

    messages: list["MessageResponse"]
    has_more: bool


class MessageResponse(BaseModel):
    id: int
    chat_id: int
    sender_id: int

    text: str
    message_type: str
    client_message_id: str | None = None

    media_key: str | None = None
    media_url: str | None = None
    media_mime_type: str | None = None
    media_size: int | None = None

    created_at: datetime
    updated_at: datetime | None = None
    is_updated: bool | None = False
    is_deleted: bool | None = False

    reply_to_message_id: int | None = None
    reply_to: MessageReplyPreview | None = None

    forwarded_from_user_id: int | None = None

    # Только для исходящих сообщений текущего пользователя: sent / read
    delivery_status: Literal["sent", "read"] | None = None

    reactions: list[ReactionGroup] = Field(default_factory=list)

    pinned_at: datetime | None = None
    pinned_by_user_id: int | None = None

    mention_user_ids: list[int] = Field(default_factory=list)

    poll: PollResponse | None = None

    class Config:
        from_attributes = True


MessageListPage.model_rebuild()
