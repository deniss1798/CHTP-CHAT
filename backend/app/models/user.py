from sqlalchemy import BigInteger, Column, DateTime, String, Text, TIMESTAMP, func

from app.db.database import Base
from app.db.types import bigint_primary_key


class User(Base):
    __tablename__ = "users"

    id = Column(
        bigint_primary_key(),
        primary_key=True,
        autoincrement=True,
        index=True,
    )
    username = Column(String(50), unique=True, nullable=False)
    email = Column(String(255), unique=True, nullable=False)
    password_hash = Column(Text, nullable=False)
    avatar_url = Column(Text, nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.now())
    last_seen_at = Column(DateTime(timezone=True), nullable=True)