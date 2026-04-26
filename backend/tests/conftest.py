import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.database import Base
from app.models.chat import Chat  # noqa: F401
from app.models.chat_member import ChatMember  # noqa: F401
from app.models.device_token import DeviceToken  # noqa: F401
from app.models.message import Message  # noqa: F401
from app.models.message_reaction import MessageReaction  # noqa: F401
from app.models.notification_setting import NotificationSetting  # noqa: F401
from app.models.pending_registration import PendingRegistration  # noqa: F401
from app.models.user import User  # noqa: F401


@pytest.fixture()
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)
        engine.dispose()
