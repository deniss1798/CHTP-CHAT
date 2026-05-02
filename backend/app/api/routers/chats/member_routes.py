from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.application.chats.member_queries import list_chat_members
from app.application.chats.membership_commands import (
    add_chat_member,
    leave_group_chat,
    remove_group_member,
)
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.chat_schema import ChatMemberAddRequest, ChatMemberResponse

router = APIRouter()


@router.get("/{chat_id}/members", response_model=list[ChatMemberResponse])
def get_chat_members(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_chat_members(
        db,
        chat_id=chat_id,
        current_user=current_user,
    )


@router.post("/{chat_id}/members", response_model=ChatMemberResponse)
def add_group_member(
    chat_id: int,
    payload: ChatMemberAddRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return add_chat_member(
        db,
        chat_id=chat_id,
        current_user=current_user,
        payload=payload,
    )


@router.post("/{chat_id}/leave", status_code=status.HTTP_204_NO_CONTENT)
def leave_chat(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    leave_group_chat(
        db,
        chat_id=chat_id,
        current_user=current_user,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete(
    "/{chat_id}/members/{member_user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_group_member(
    chat_id: int,
    member_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    remove_group_member(
        db,
        chat_id=chat_id,
        member_user_id=member_user_id,
        current_user=current_user,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
