from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.application.messages.pin_commands import (
    list_pinned_messages,
    pin_message as execute_pin_message,
    unpin_message as execute_unpin_message,
)
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.message_schema import MessageResponse

router = APIRouter()


@router.post("/{message_id}/pin", response_model=MessageResponse)
async def pin_message_endpoint(
    message_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await execute_pin_message(
        db,
        current_user=current_user,
        message_id=message_id,
    )


@router.delete("/{message_id}/pin", response_model=MessageResponse)
async def unpin_message_endpoint(
    message_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await execute_unpin_message(
        db,
        current_user=current_user,
        message_id=message_id,
    )


@router.get("/chats/{chat_id}/pinned", response_model=list[MessageResponse])
def list_pinned_messages_endpoint(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_pinned_messages(
        db,
        current_user=current_user,
        chat_id=chat_id,
    )
