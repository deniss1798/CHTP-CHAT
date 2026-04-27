import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.rate_limit import rate_limiter
from app.db.database import Base
from app.db.database import get_db
from app.main import app
from app.models.call import Call  # noqa: F401
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


@pytest.fixture()
def api_client(db_session):
    def override_get_db():
        yield db_session

    rate_limiter.clear()
    app.dependency_overrides[get_db] = override_get_db
    try:
        with TestClient(app) as client:
            yield client
    finally:
        app.dependency_overrides.clear()
        rate_limiter.clear()
