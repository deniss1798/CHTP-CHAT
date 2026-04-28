from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.application.chats.member_preferences import update_member_chat_preferences
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.chat_schema import ChatMemberPreferencesPayload, ChatResponse

router = APIRouter()


@router.patch("/{chat_id}/member-preferences", response_model=ChatResponse)
def patch_member_preferences(
    chat_id: int,
    payload: ChatMemberPreferencesPayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if payload.is_archived is None and payload.notifications_muted is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update",
        )
    try:
        return update_member_chat_preferences(
            db,
            chat_id=chat_id,
            current_user=current_user,
            is_archived=payload.is_archived,
            notifications_muted=payload.notifications_muted,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e),
        ) from e
