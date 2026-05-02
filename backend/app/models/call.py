from sqlalchemy import BigInteger, Column, DateTime, ForeignKey, Index, Integer, String, Text
from sqlalchemy.sql import func

from app.db.database import Base
from app.db.types import bigint_primary_key


class Call(Base):
    __tablename__ = "calls"
    __table_args__ = (
        Index("ix_calls_started_at_id", "started_at", "id"),
        Index("ix_calls_chat_started_id", "chat_id", "started_at", "id"),
    )

    id = Column(
        bigint_primary_key(),
        primary_key=True,
        autoincrement=True,
        index=True,
    )
    chat_id = Column(
        BigInteger,
        ForeignKey("chats.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    initiator_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    type = Column(String(32), nullable=False, default="voice")
    status = Column(String(32), nullable=False, default="created", index=True)
    started_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    accepted_at = Column(DateTime(timezone=True), nullable=True)
    ended_at = Column(DateTime(timezone=True), nullable=True)
    duration_seconds = Column(Integer, nullable=True)
    client_call_id = Column(Text, nullable=True, unique=True)
