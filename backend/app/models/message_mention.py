from sqlalchemy import BigInteger, Column, ForeignKey, Index, UniqueConstraint

from app.db.database import Base
from app.db.types import bigint_primary_key


class MessageMention(Base):
    __tablename__ = "message_mentions"

    id = Column(bigint_primary_key(), primary_key=True, autoincrement=True)
    message_id = Column(
        BigInteger,
        ForeignKey("messages.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    __table_args__ = (
        UniqueConstraint("message_id", "user_id", name="uq_message_mentions_message_user"),
        Index("ix_message_mentions_user", "user_id"),
    )
