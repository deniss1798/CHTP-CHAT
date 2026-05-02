from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.application.messages.commands import (
    delete_message as execute_delete_message,
    forward_message as execute_forward_message,
    send_text_message as execute_send_text_message,
    update_text_message as execute_update_text_message,
)
from app.core.dependencies import get_current_user
from app.core.rate_limit import MESSAGE_SEND_RULE, rate_limiter
from app.db.database import get_db
from app.models.user import User
from app.schemas.message_schema import (
    ForwardMessageRequest,
    MessageCreate,
    MessageResponse,
    MessageUpdate,
)

router = APIRouter()


@router.post("/", response_model=MessageResponse)
async def send_message(
    message: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rate_limiter.check(str(current_user.id), MESSAGE_SEND_RULE)
    return await execute_send_text_message(
        db,
        current_user=current_user,
        payload=message,
    )


@router.post("/forward", response_model=MessageResponse)
async def forward_message_endpoint(
    payload: ForwardMessageRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await execute_forward_message(
        db,
        current_user=current_user,
        payload=payload,
    )


@router.patch("/{message_id}", response_model=MessageResponse)
async def update_message(
    message_id: int,
    message_data: MessageUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await execute_update_text_message(
        db,
        current_user=current_user,
        message_id=message_id,
        payload=message_data,
    )


@router.delete("/{message_id}")
async def delete_message(
    message_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await execute_delete_message(
        db,
        current_user=current_user,
        message_id=message_id,
    )
