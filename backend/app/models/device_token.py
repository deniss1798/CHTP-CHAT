from sqlalchemy import Boolean, Column, DateTime, ForeignKey, BigInteger, Index, String
from sqlalchemy.sql import func

from app.db.database import Base
from app.db.types import bigint_primary_key


class DeviceToken(Base):
    __tablename__ = "device_tokens"
    __table_args__ = (
        Index(
            "ix_device_tokens_user_updated_id",
            "user_id",
            "updated_at",
            "id",
        ),
    )

    id = Column(
        bigint_primary_key(),
        primary_key=True,
        autoincrement=True,
        index=True,
    )
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