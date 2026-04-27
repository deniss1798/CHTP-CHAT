from datetime import datetime

from pydantic import BaseModel, Field


class StoryUserBrief(BaseModel):
    id: int
    username: str
    avatar_url: str | None = None


class StoryFeedEntry(BaseModel):
    user: StoryUserBrief
    is_self: bool = False
    has_unseen: bool = False
    story_count: int = 0
    latest_story_at: datetime | None = None


class StoryFeedResponse(BaseModel):
    entries: list[StoryFeedEntry]


class StoryItem(BaseModel):
    id: int
    media_url: str
    media_type: str = Field(description="image | video")
    caption: str | None = None
    created_at: datetime
    expires_at: datetime


class UserStoriesResponse(BaseModel):
    user: StoryUserBrief
    stories: list[StoryItem]


class StoryCreatedResponse(BaseModel):
    id: int
    media_url: str
    media_type: str
    caption: str | None = None
    created_at: datetime
    expires_at: datetime


class StoryViewAck(BaseModel):
    ok: bool = True


class StoryDeleteAck(BaseModel):
    ok: bool = True
