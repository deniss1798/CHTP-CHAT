from sqlalchemy import BigInteger, Column, ForeignKey, String, Text, TIMESTAMP, UniqueConstraint, func
from sqlalchemy.orm import relationship

from app.db.database import Base
from app.db.types import bigint_primary_key


class Chat(Base):
    __tablename__ = "chats"

    id = Column(
        bigint_primary_key(),
        primary_key=True,
        autoincrement=True,
        index=True,
    )
    type = Column(String(20), nullable=False)
    title = Column(String(255), nullable=True)
    avatar_url = Column(Text, nullable=True)
    created_by = Column(BigInteger, ForeignKey("users.id"), nullable=True)
    private_pair_key = Column(String(64), nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())

    members = relationship("ChatMember", back_populates="chat", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("private_pair_key", name="uq_chats_private_pair_key"),
    )
