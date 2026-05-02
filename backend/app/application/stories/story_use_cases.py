"""Сценарии сторис: лента (контакты из приватных чатов), просмотр, загрузка."""

from __future__ import annotations

from datetime import datetime, timedelta

from fastapi import HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.story import Story, StoryView
from app.models.user import User
from app.schemas.story_schema import (
    StoryCreatedResponse,
    StoryDeleteAck,
    StoryFeedEntry,
    StoryFeedResponse,
    StoryItem,
    StoryUserBrief,
    StoryViewAck,
    UserStoriesResponse,
)
from app.services import media_service as media_svc


def _now() -> datetime:
    return datetime.utcnow()


def _private_chat_peer_ids(db: Session, user_id: int) -> set[int]:
    rows = (
        db.query(ChatMember.chat_id)
        .join(Chat, Chat.id == ChatMember.chat_id)
        .filter(ChatMember.user_id == user_id, Chat.type == "private")
        .all()
    )
    chat_ids = [r[0] for r in rows]
    if not chat_ids:
        return set()
    peers = (
        db.query(ChatMember.user_id)
        .filter(ChatMember.chat_id.in_(chat_ids), ChatMember.user_id != user_id)
        .distinct()
        .all()
    )
    return {p[0] for p in peers}


def _can_view_user_stories(db: Session, viewer_id: int, author_id: int) -> bool:
    if viewer_id == author_id:
        return True
    return author_id in _private_chat_peer_ids(db, viewer_id)


def _user_brief(db: Session, uid: int) -> StoryUserBrief:
    u = db.query(User).filter(User.id == uid).first()
    if not u:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return StoryUserBrief(id=u.id, username=u.username, avatar_url=u.avatar_url)


def build_feed(db: Session, current: User) -> StoryFeedResponse:
    now = _now()
    peers = _private_chat_peer_ids(db, current.id)
    allowed_ids = peers | {current.id}

    user_ids_with_stories = (
        db.query(Story.user_id)
        .filter(Story.expires_at > now, Story.user_id.in_(allowed_ids))
        .distinct()
        .all()
    )
    uid_set = {row[0] for row in user_ids_with_stories}

    entries: list[StoryFeedEntry] = []

    def entry_for(uid: int) -> StoryFeedEntry | None:
        if uid not in allowed_ids:
            return None
        u = db.query(User).filter(User.id == uid).first()
        if not u:
            return None
        stories = (
            db.query(Story)
            .filter(Story.user_id == uid, Story.expires_at > now)
            .order_by(Story.created_at.asc())
            .all()
        )
        if not stories and uid != current.id:
            return None

        viewed_ids_subq = (
            db.query(StoryView.story_id).filter(StoryView.viewer_user_id == current.id).subquery()
        )
        unseen = 0
        latest_at: datetime | None = None
        for s in stories:
            if latest_at is None or s.created_at > latest_at:
                latest_at = s.created_at
            if uid == current.id:
                continue
            v = (
                db.query(StoryView)
                .filter(StoryView.story_id == s.id, StoryView.viewer_user_id == current.id)
                .first()
            )
            if v is None:
                unseen += 1

        has_unseen = uid != current.id and unseen > 0
        return StoryFeedEntry(
            user=StoryUserBrief(id=u.id, username=u.username, avatar_url=u.avatar_url),
            is_self=(uid == current.id),
            has_unseen=has_unseen,
            story_count=len(stories),
            latest_story_at=latest_at,
        )

    self_e = entry_for(current.id)
    if self_e is None:
        u = db.query(User).filter(User.id == current.id).first()
        if u:
            self_e = StoryFeedEntry(
                user=StoryUserBrief(id=u.id, username=u.username, avatar_url=u.avatar_url),
                is_self=True,
                has_unseen=False,
                story_count=0,
                latest_story_at=None,
            )

    if self_e:
        entries.append(self_e)

    other_uids = sorted(
        (uid_set - {current.id}),
        key=lambda uid: (
            db.query(Story.created_at)
            .filter(Story.user_id == uid, Story.expires_at > now)
            .order_by(Story.created_at.desc())
            .limit(1)
            .scalar()
            or datetime.min
        ),
        reverse=True,
    )

    for uid in other_uids:
        e = entry_for(uid)
        if e and e.story_count > 0:
            entries.append(e)

    return StoryFeedResponse(entries=entries)


def get_user_stories(db: Session, current: User, author_id: int) -> UserStoriesResponse:
    if not _can_view_user_stories(db, current.id, author_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot view these stories")

    now = _now()
    rows = (
        db.query(Story)
        .filter(Story.user_id == author_id, Story.expires_at > now)
        .order_by(Story.created_at.asc())
        .all()
    )
    items: list[StoryItem] = []
    storage = media_svc.presign_story_media_url
    for s in rows:
        url = storage(s.media_key)
        if not url:
            continue
        items.append(
            StoryItem(
                id=s.id,
                media_url=url,
                media_type=s.media_type,
                caption=s.caption,
                created_at=s.created_at,
                expires_at=s.expires_at,
            )
        )
    u = _user_brief(db, author_id)
    return UserStoriesResponse(user=u, stories=items)


async def create_story(
    db: Session,
    current: User,
    *,
    file: UploadFile,
    media_type: str,
    caption: str | None,
) -> StoryCreatedResponse:
    media_type = (media_type or "").strip().lower()
    if media_type not in {"image", "video"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="media_type must be image or video",
        )

    media_svc.require_private_s3_or_503()
    cap = (caption or "").strip()[:1024] or None
    expires_at = _now() + timedelta(hours=24)

    if media_type == "image":
        content, content_type = await media_svc.read_and_validate_photo(file)
        media_key, _ = media_svc.upload_private_story_image(
            user_id=current.id,
            content=content,
            content_type=content_type,
        )
    else:
        content, extension, media_ct = await media_svc.read_and_prepare_video(file)
        media_key, _ = media_svc.upload_private_story_video(
            user_id=current.id,
            content=content,
            extension=extension,
            content_type=media_ct,
        )

    story = Story(
        user_id=current.id,
        media_key=media_key,
        media_type=media_type,
        caption=cap,
        expires_at=expires_at,
    )
    db.add(story)
    db.commit()
    db.refresh(story)

    url = media_svc.presign_story_media_url(story.media_key) or ""
    return StoryCreatedResponse(
        id=story.id,
        media_url=url,
        media_type=story.media_type,
        caption=story.caption,
        created_at=story.created_at,
        expires_at=story.expires_at,
    )


def mark_story_viewed(db: Session, current: User, story_id: int) -> StoryViewAck:
    story = db.query(Story).filter(Story.id == story_id).first()
    if not story or story.expires_at <= _now():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Story not found")

    if not _can_view_user_stories(db, current.id, story.user_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot view this story")

    exists = (
        db.query(StoryView)
        .filter(StoryView.story_id == story_id, StoryView.viewer_user_id == current.id)
        .first()
    )
    if not exists:
        db.add(StoryView(story_id=story_id, viewer_user_id=current.id))
        db.commit()

    return StoryViewAck()


def delete_story(db: Session, current: User, story_id: int) -> StoryDeleteAck:
    story = db.query(Story).filter(Story.id == story_id).first()
    if not story:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Story not found")
    if story.user_id != current.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your story")

    media_svc.delete_private_media_key(story.media_key)
    db.delete(story)
    db.commit()
    return StoryDeleteAck()
