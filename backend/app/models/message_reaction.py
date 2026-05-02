from sqlalchemy import BigInteger, Column, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.sql import func

from app.db.database import Base
from app.db.types import bigint_primary_key


class MessageReaction(Base):
    __tablename__ = "message_reactions"
    __table_args__ = (
        UniqueConstraint(
            "message_id", "user_id", "emoji", name="uq_message_reaction_user_emoji"
        ),
    )

    id = Column(
        bigint_primary_key(),
        primary_key=True,
        autoincrement=True,
    )
    message_id = Column(
        BigInteger, ForeignKey("messages.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    emoji = Column(String(32), nullable=False)
    created_at = Column(DateTime(timezone=False), server_default=func.now())
