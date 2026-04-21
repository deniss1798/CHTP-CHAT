from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.application.messages.queries import list_chat_messages
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.message_schema import MessageListPage

router = APIRouter()


@router.get("/chat/{chat_id}", response_model=MessageListPage)
def get_chat_messages(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    before_message_id: int | None = Query(
        default=None,
        ge=1,
        description="Загрузить сообщения старее этого id (для прокрутки вверх)",
    ),
    limit: int | None = Query(
        default=None,
        ge=1,
        le=100,
        description="Размер страницы (по умолчанию 50)",
    ),
):
    return list_chat_messages(
        db,
        current_user=current_user,
        chat_id=chat_id,
        before_message_id=before_message_id,
        limit=limit,
    )
