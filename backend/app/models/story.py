from sqlalchemy import BigInteger, Column, DateTime, ForeignKey, Index, String, Text, UniqueConstraint
from sqlalchemy.sql import func

from app.db.database import Base
from app.db.types import bigint_primary_key


class Story(Base):
    __tablename__ = "stories"

    id = Column(
        bigint_primary_key(),
        primary_key=True,
        autoincrement=True,
        index=True,
    )
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    media_key = Column(Text, nullable=False)
    media_type = Column(String(20), nullable=False)
    caption = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=False), server_default=func.now())
    expires_at = Column(DateTime(timezone=False), nullable=False, index=True)

    __table_args__ = (
        Index("ix_stories_user_expires", "user_id", "expires_at"),
    )


class StoryView(Base):
    __tablename__ = "story_views"

    id = Column(
        bigint_primary_key(),
        primary_key=True,
        autoincrement=True,
    )
    story_id = Column(
        BigInteger,
        ForeignKey("stories.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    viewer_user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    viewed_at = Column(DateTime(timezone=False), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("story_id", "viewer_user_id", name="uq_story_views_story_viewer"),
        Index("ix_story_views_viewer", "viewer_user_id"),
    )
