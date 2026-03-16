from sqlalchemy import BigInteger, Column, ForeignKey, String, TIMESTAMP, func
from sqlalchemy.orm import relationship

from app.db.database import Base


class Chat(Base):
    __tablename__ = "chats"

    id = Column(BigInteger, primary_key=True, index=True)
    type = Column(String(20), nullable=False)
    title = Column(String(255), nullable=True)
    created_by = Column(BigInteger, ForeignKey("users.id"), nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())

    members = relationship("ChatMember", back_populates="chat", cascade="all, delete-orphan")