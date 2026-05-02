from sqlalchemy import BigInteger, Boolean, Column, DateTime, ForeignKey
from sqlalchemy.sql import func

from app.db.database import Base


class NotificationSetting(Base):
    __tablename__ = "notification_settings"

    user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    notifications_enabled = Column(Boolean, nullable=False, default=True)
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
