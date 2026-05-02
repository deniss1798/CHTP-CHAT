from fastapi import APIRouter, Depends, File, UploadFile
from sqlalchemy.orm import Session

from app.application.chats.group_commands import upload_group_chat_avatar
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.chat_schema import ChatDetailResponse

router = APIRouter()


@router.patch("/{chat_id}/avatar", response_model=ChatDetailResponse)
async def update_chat_avatar(
    chat_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await upload_group_chat_avatar(
        db,
        chat_id=chat_id,
        current_user=current_user,
        file=file,
    )
