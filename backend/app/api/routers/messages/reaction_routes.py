from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.application.messages.reaction_commands import (
    add_message_reaction as execute_add_message_reaction,
    remove_message_reaction as execute_remove_message_reaction,
)
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.message_schema import MessageReactionBody, MessageResponse

router = APIRouter()


@router.post("/{message_id}/reactions", response_model=MessageResponse)
async def add_reaction(
    message_id: int,
    body: MessageReactionBody,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await execute_add_message_reaction(
        db,
        current_user=current_user,
        message_id=message_id,
        emoji=body.emoji,
    )


@router.delete("/{message_id}/reactions", response_model=MessageResponse)
async def remove_reaction(
    message_id: int,
    emoji: str = Query(..., min_length=1, max_length=32),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """DELETE без JSON-тела: emoji в query (надёжно для веб-клиентов и прокси)."""
    return await execute_remove_message_reaction(
        db,
        current_user=current_user,
        message_id=message_id,
        emoji=emoji,
    )
