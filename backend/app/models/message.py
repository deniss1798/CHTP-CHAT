from sqlalchemy import Boolean, Column, DateTime, ForeignKey, BigInteger, Text, String
from sqlalchemy.sql import func

from app.db.database import Base


class Message(Base):
    __tablename__ = "messages"

    id = Column(BigInteger, primary_key=True, index=True)
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

    message_type = Column(String, nullable=False, default="text")
    media_key = Column(Text, nullable=True)
    media_url = Column(Text, nullable=True)
    media_mime_type = Column(String, nullable=True)
    media_size = Column(BigInteger, nullable=True)

    created_at = Column(DateTime(timezone=False), server_default=func.now())
    updated_at = Column(DateTime(timezone=False), server_default=func.now(), onupdate=func.now())
    is_updated = Column(Boolean, default=False)