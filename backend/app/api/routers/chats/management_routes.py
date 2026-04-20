from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.application.chats.group_commands import rename_group_chat
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.chat_schema import ChatDetailResponse, ChatUpdate

router = APIRouter()


@router.patch("/{chat_id}", response_model=ChatDetailResponse)
def update_group_chat(
    chat_id: int,
    payload: ChatUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return rename_group_chat(
        db,
        chat_id=chat_id,
        current_user=current_user,
        payload=payload,
    )
