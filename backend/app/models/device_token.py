from sqlalchemy import Boolean, Column, DateTime, ForeignKey, BigInteger, String
from sqlalchemy.sql import func

from app.db.database import Base


class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    token = Column(String, nullable=False, unique=True, index=True)
    platform = Column(String, nullable=True)
    device_name = Column(String, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )