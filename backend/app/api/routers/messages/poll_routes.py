from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.application.messages.poll_commands import (
    close_poll as execute_close_poll,
    create_poll_message as execute_create_poll,
    vote_in_poll as execute_vote_in_poll,
)
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.message_schema import (
    MessageResponse,
    PollCreate,
    PollVoteRequest,
)

router = APIRouter()


@router.post("/polls", response_model=MessageResponse)
async def create_poll(
    payload: PollCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await execute_create_poll(
        db,
        current_user=current_user,
        payload=payload,
    )


@router.post("/{message_id}/poll/vote", response_model=MessageResponse)
async def poll_vote(
    message_id: int,
    payload: PollVoteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await execute_vote_in_poll(
        db,
        current_user=current_user,
        message_id=message_id,
        payload=payload,
    )


@router.post("/{message_id}/poll/close", response_model=MessageResponse)
async def poll_close(
    message_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await execute_close_poll(
        db,
        current_user=current_user,
        message_id=message_id,
    )
