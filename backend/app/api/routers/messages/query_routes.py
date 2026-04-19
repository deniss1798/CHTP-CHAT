from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.application.messages.queries import list_chat_messages
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.message_schema import MessageResponse

router = APIRouter()


@router.get("/chat/{chat_id}", response_model=list[MessageResponse])
def get_chat_messages(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_chat_messages(db, current_user=current_user, chat_id=chat_id)
