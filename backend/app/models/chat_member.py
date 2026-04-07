from sqlalchemy import BigInteger, Column, ForeignKey, String, TIMESTAMP, func, UniqueConstraint
from sqlalchemy.orm import relationship

from app.db.database import Base


class ChatMember(Base):
    __tablename__ = "chat_members"

    id = Column(BigInteger, primary_key=True, index=True)
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

    __table_args__ = (
        UniqueConstraint("chat_id", "user_id", name="uq_chat_members_chat_user"),
    )

    chat = relationship("Chat", back_populates="members")