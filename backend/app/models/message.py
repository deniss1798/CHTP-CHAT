from sqlalchemy import Boolean, Column, DateTime, ForeignKey, BigInteger, Index, Text, String, UniqueConstraint
from sqlalchemy.sql import func

from app.db.database import Base
from app.db.types import bigint_primary_key


class Message(Base):
    __tablename__ = "messages"

    id = Column(
        bigint_primary_key(),
        primary_key=True,
        autoincrement=True,
        index=True,
    )
    chat_id = Column(BigInteger, ForeignKey("chats.id"), nullable=False, index=True)
    sender_id = Column(BigInteger, ForeignKey("users.id"), nullable=False, index=True)

    reply_to_message_id = Column(
        BigInteger,
        ForeignKey("messages.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    forwarded_from_user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    text = Column(Text, nullable=False)
    client_message_id = Column(String(128), nullable=True)

    message_type = Column(String, nullable=False, default="text")
    media_key = Column(Text, nullable=True)
    media_url = Column(Text, nullable=True)
    media_mime_type = Column(String, nullable=True)
    media_size = Column(BigInteger, nullable=True)

    created_at = Column(DateTime(timezone=False), server_default=func.now())
    updated_at = Column(DateTime(timezone=False), server_default=func.now(), onupdate=func.now())
    is_updated = Column(Boolean, default=False)
    is_deleted = Column(Boolean, nullable=False, default=False)

    pinned_at = Column(DateTime(timezone=False), nullable=True)
    pinned_by_user_id = Column(BigInteger, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    __table_args__ = (
        UniqueConstraint(
            "sender_id",
            "client_message_id",
            name="uq_messages_sender_client_message_id",
        ),
        Index("ix_messages_chat_id_id", "chat_id", "id"),
        Index("ix_messages_chat_id_created_at_id", "chat_id", "created_at", "id"),
        Index(
            "ix_messages_chat_pinned",
            "chat_id",
            "pinned_at",
        ),
    )
