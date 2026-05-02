from sqlalchemy import BigInteger, Boolean, Column, false as sa_false, ForeignKey, Index, String, TIMESTAMP, func, UniqueConstraint
from sqlalchemy.orm import relationship

from app.db.database import Base
from app.db.types import bigint_primary_key


class ChatMember(Base):
    __tablename__ = "chat_members"

    id = Column(
        bigint_primary_key(),
        primary_key=True,
        autoincrement=True,
        index=True,
    )
    chat_id = Column(BigInteger, ForeignKey("chats.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role = Column(String(20), nullable=False, default="member")
    joined_at = Column(TIMESTAMP, server_default=func.now())
    last_read_message_id = Column(
        BigInteger,
        ForeignKey("messages.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    is_archived = Column(Boolean, nullable=False, server_default=sa_false())
    notifications_muted = Column(Boolean, nullable=False, server_default=sa_false())
    is_pinned = Column(Boolean, nullable=False, server_default=sa_false())

    __table_args__ = (
        UniqueConstraint("chat_id", "user_id", name="uq_chat_members_chat_user"),
        Index("ix_chat_members_user_chat", "user_id", "chat_id"),
    )

    chat = relationship("Chat", back_populates="members")