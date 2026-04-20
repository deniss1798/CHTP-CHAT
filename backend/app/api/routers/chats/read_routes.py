from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.application.chats.member_queries import list_chat_read_state
from app.application.chats.read_tracking import mark_chat_read
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.chat_schema import MarkChatReadRequest, MemberReadState

router = APIRouter()


@router.get("/{chat_id}/read-state", response_model=list[MemberReadState])
def get_chat_read_state(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_chat_read_state(
        db,
        chat_id=chat_id,
        current_user=current_user,
    )


@router.post("/{chat_id}/read")
async def mark_read(
    chat_id: int,
    body: MarkChatReadRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await mark_chat_read(
        db,
        chat_id=chat_id,
        current_user=current_user,
        message_id=body.message_id,
    )
