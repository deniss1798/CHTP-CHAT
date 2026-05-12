from sqlalchemy import (
    BigInteger,
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.database import Base
from app.db.types import bigint_primary_key


class Poll(Base):
    __tablename__ = "polls"

    id = Column(bigint_primary_key(), primary_key=True, autoincrement=True)
    message_id = Column(
        BigInteger,
        ForeignKey("messages.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )
    question = Column(Text, nullable=False)
    allows_multiple = Column(Boolean, nullable=False, default=False)
    is_anonymous = Column(Boolean, nullable=False, default=False)
    is_closed = Column(Boolean, nullable=False, default=False)
    created_at = Column(
        DateTime(timezone=False), nullable=False, server_default=func.now()
    )

    options = relationship(
        "PollOption",
        back_populates="poll",
        cascade="all, delete-orphan",
        order_by="PollOption.position",
    )


class PollOption(Base):
    __tablename__ = "poll_options"

    id = Column(bigint_primary_key(), primary_key=True, autoincrement=True)
    poll_id = Column(
        BigInteger,
        ForeignKey("polls.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    position = Column(Integer, nullable=False)
    text = Column(Text, nullable=False)

    __table_args__ = (
        UniqueConstraint("poll_id", "position", name="uq_poll_options_poll_position"),
    )

    poll = relationship("Poll", back_populates="options")


class PollVote(Base):
    __tablename__ = "poll_votes"

    id = Column(bigint_primary_key(), primary_key=True, autoincrement=True)
    poll_id = Column(
        BigInteger,
        ForeignKey("polls.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    option_id = Column(
        BigInteger,
        ForeignKey("poll_options.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    created_at = Column(
        DateTime(timezone=False), nullable=False, server_default=func.now()
    )

    __table_args__ = (
        UniqueConstraint(
            "poll_id", "option_id", "user_id", name="uq_poll_votes_poll_option_user"
        ),
        Index("ix_poll_votes_poll_user", "poll_id", "user_id"),
    )
