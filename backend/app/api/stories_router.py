from fastapi import APIRouter, Depends, File, Form, UploadFile
from sqlalchemy.orm import Session

from app.application.stories.story_use_cases import (
    build_feed,
    create_story,
    delete_story,
    get_user_stories,
    mark_story_viewed,
)
from app.core.dependencies import get_current_user
from app.core.rate_limit import MEDIA_UPLOAD_RULE, rate_limiter
from app.db.database import get_db
from app.models.user import User
from app.schemas.story_schema import (
    StoryCreatedResponse,
    StoryDeleteAck,
    StoryFeedResponse,
    StoryViewAck,
    UserStoriesResponse,
)

router = APIRouter(prefix="/stories", tags=["stories"])


@router.get("/feed", response_model=StoryFeedResponse)
def stories_feed(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return build_feed(db, current_user)


@router.get("/user/{author_id}", response_model=UserStoriesResponse)
def stories_by_user(
    author_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_user_stories(db, current_user, author_id)


@router.post("", response_model=StoryCreatedResponse)
async def stories_create(
    file: UploadFile = File(...),
    media_type: str = Form(...),
    caption: str | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rate_limiter.check(str(current_user.id), MEDIA_UPLOAD_RULE)
    return await create_story(db, current_user, file=file, media_type=media_type, caption=caption)


@router.post("/{story_id}/view", response_model=StoryViewAck)
def stories_mark_viewed(
    story_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return mark_story_viewed(db, current_user, story_id)


@router.delete("/{story_id}", response_model=StoryDeleteAck)
def stories_delete(
    story_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return delete_story(db, current_user, story_id)
