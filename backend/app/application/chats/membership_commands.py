from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.domain.policies.chat_access import require_chat_member
from app.domain.policies.group_chat_policy import (
    require_group_chat,
    require_group_creator,
)
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.message import Message
from app.models.user import User
from app.schemas.chat_schema import ChatMemberAddRequest, ChatMemberResponse


def _delete_chat_if_empty(db: Session, *, chat: Chat) -> None:
    remaining_members = (
        db.query(ChatMember).filter(ChatMember.chat_id == chat.id).count()
    )
    if remaining_members == 0:
        db.query(Message).filter(Message.chat_id == chat.id).delete()
        db.delete(chat)


def _promote_next_group_owner(db: Session, *, chat: Chat) -> None:
    next_owner = (
        db.query(ChatMember)
        .filter(ChatMember.chat_id == chat.id)
        .order_by(ChatMember.user_id.asc())
        .first()
    )
    if next_owner is None:
        return

    chat.created_by = next_owner.user_id
    next_owner.role = "owner"
    db.add(chat)
    db.add(next_owner)


def add_chat_member(
    db: Session,
    *,
    chat_id: int,
    current_user: User,
    payload: ChatMemberAddRequest,
) -> ChatMemberResponse:
    chat = require_group_chat(
        db.query(Chat).filter(Chat.id == chat_id).first(),
        detail="You can add members only to group chats",
    )
    require_chat_member(db, chat_id, current_user)

    if payload.user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are already in this chat",
        )

    user_to_add = db.query(User).filter(User.id == payload.user_id).first()
    if not user_to_add:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    existing_member = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat.id,
            ChatMember.user_id == payload.user_id,
        )
        .first()
    )
    if existing_member:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User is already a member of this chat",
        )

    db.add(
        ChatMember(
            chat_id=chat.id,
            user_id=payload.user_id,
            role="member",
        )
    )
    db.commit()

    return ChatMemberResponse(
        id=user_to_add.id,
        username=user_to_add.username,
        email=user_to_add.email,
        avatar_url=user_to_add.avatar_url,
        role="member",
        last_seen_at=user_to_add.last_seen_at,
    )


def leave_group_chat(
    db: Session,
    *,
    chat_id: int,
    current_user: User,
) -> None:
    chat = require_group_chat(
        db.query(Chat).filter(Chat.id == chat_id).first(),
        detail="Only group chats can be left",
    )
    membership = require_chat_member(db, chat.id, current_user)
    current_user_id = current_user.id

    if chat.created_by == current_user_id:
        next_owner = (
            db.query(ChatMember)
            .filter(
                ChatMember.chat_id == chat.id,
                ChatMember.user_id != current_user_id,
            )
            .order_by(ChatMember.user_id.asc())
            .first()
        )
        if next_owner is not None:
            chat.created_by = next_owner.user_id
            next_owner.role = "owner"
            db.add(chat)
            db.add(next_owner)

    db.delete(membership)
    db.flush()
    _delete_chat_if_empty(db, chat=chat)
    db.commit()


def remove_group_member(
    db: Session,
    *,
    chat_id: int,
    member_user_id: int,
    current_user: User,
) -> None:
    chat = require_group_chat(
        db.query(Chat).filter(Chat.id == chat_id).first(),
        detail="Only for group chats",
    )
    require_chat_member(db, chat.id, current_user)
    require_group_creator(chat, current_user)

    if member_user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Use leave endpoint to exit the group",
        )

    target_membership = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat.id,
            ChatMember.user_id == member_user_id,
        )
        .first()
    )
    if not target_membership:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User is not a member",
        )

    removing_group_creator = chat.created_by == member_user_id
    db.delete(target_membership)
    db.flush()

    if removing_group_creator:
        _promote_next_group_owner(db, chat=chat)

    _delete_chat_if_empty(db, chat=chat)
    db.commit()
