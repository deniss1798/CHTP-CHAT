from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import case, func
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.user import User
from app.schemas.chat_schema import (
    ChatCreate,
    ChatDetailResponse,
    ChatMemberAddRequest,
    ChatMemberResponse,
    ChatResponse,
    UserShort,
)

router = APIRouter(prefix="/chats", tags=["Chats"])


@router.post("/", response_model=ChatResponse)
def create_chat(
    chat_data: ChatCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if chat_data.type == "private":
        if len(chat_data.member_ids) != 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Private chat must contain exactly one target user",
            )

        if chat_data.member_ids[0] == current_user.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You cannot create a private chat with yourself",
            )

    if chat_data.type == "group":
        if not chat_data.title or not chat_data.title.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Group chat must have a title",
            )

    all_member_ids = set(chat_data.member_ids)
    all_member_ids.add(current_user.id)

    users_count = db.query(User).filter(User.id.in_(all_member_ids)).count()
    if users_count != len(all_member_ids):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="One or more users do not exist",
        )

    if chat_data.type == "private":
        member_ids = list(all_member_ids)

        existing_chat = (
            db.query(Chat.id)
            .join(ChatMember, ChatMember.chat_id == Chat.id)
            .filter(Chat.type == "private")
            .group_by(Chat.id)
            .having(func.count(ChatMember.user_id) == len(member_ids))
            .having(
                func.sum(
                    case(
                        (ChatMember.user_id.in_(member_ids), 1),
                        else_=0,
                    )
                )
                == len(member_ids)
            )
            .first()
        )

        if existing_chat:
            chat = db.query(Chat).filter(Chat.id == existing_chat.id).first()
         return ChatResponse(
                id=chat.id,
                type=chat.type,
                title=chat.title,
                avatar_url=chat.avatar_url,
                created_by=chat.created_by,
            )

    new_chat = Chat(
        type=chat_data.type,
        title=chat_data.title.strip() if chat_data.title else None,
        created_by=current_user.id,
    )

    db.add(new_chat)
    db.flush()

    for user_id in all_member_ids:
        role = "owner" if user_id == current_user.id else "member"
        db.add(
            ChatMember(
                chat_id=new_chat.id,
                user_id=user_id,
                role=role,
            )
        )

    db.commit()
    db.refresh(new_chat)

      return ChatResponse(
        id=new_chat.id,
        type=new_chat.type,
        title=new_chat.title,
        avatar_url=new_chat.avatar_url,
        created_by=new_chat.created_by,
    )


@router.get("/", response_model=list[ChatResponse])
def get_my_chats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chats = (
        db.query(Chat)
        .join(ChatMember, ChatMember.chat_id == Chat.id)
        .filter(ChatMember.user_id == current_user.id)
        .order_by(Chat.id.desc())
        .all()
    )

    result = []

    for chat in chats:
        chat_title = chat.title
        chat_avatar_url = chat.avatar_url

        if chat.type == "private":
            other_user = (
                db.query(User)
                .join(ChatMember, ChatMember.user_id == User.id)
                .filter(
                    ChatMember.chat_id == chat.id,
                    User.id != current_user.id,
                )
                .first()
            )

            if other_user:
                chat_title = other_user.username
                chat_avatar_url = other_user.avatar_url

        result.append(
            ChatResponse(
                id=chat.id,
                type=chat.type,
                title=chat_title,
                avatar_url=chat_avatar_url,
                created_by=chat.created_by,
            )
        )

    return result


@router.get("/{chat_id}", response_model=ChatDetailResponse)
def get_chat_detail(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = db.query(Chat).filter(Chat.id == chat_id).first()

    if not chat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat not found",
        )

    chat_member = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == current_user.id,
        )
        .first()
    )

    if not chat_member:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this chat",
        )

    users = (
        db.query(User)
        .join(ChatMember, ChatMember.user_id == User.id)
        .filter(ChatMember.chat_id == chat_id)
        .order_by(User.username.asc())
        .all()
    )

    members = [
        UserShort(
            id=user.id,
            username=user.username,
            email=user.email,
            avatar_url=user.avatar_url,
        )
        for user in users
    ]

    chat_title = chat.title
    chat_avatar_url = chat.avatar_url

    if chat.type == "private":
        other_user = next((user for user in users if user.id != current_user.id), None)
        if other_user:
            chat_title = other_user.username
            chat_avatar_url = other_user.avatar_url

    return ChatDetailResponse(
        id=chat.id,
        type=chat.type,
        title=chat_title,
        avatar_url=chat_avatar_url,
        created_by=chat.created_by,
        members=members,
    )


@router.get("/{chat_id}/members", response_model=list[ChatMemberResponse])
def get_chat_members(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat_member = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == current_user.id,
        )
        .first()
    )

    if not chat_member:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this chat",
        )

    members = (
        db.query(User, ChatMember.role)
        .join(ChatMember, ChatMember.user_id == User.id)
        .filter(ChatMember.chat_id == chat_id)
        .all()
    )

    return [
        ChatMemberResponse(
            id=user.id,
            username=user.username,
            email=user.email,
            role=role,
        )
        for user, role in members
    ]


@router.post("/{chat_id}/members", response_model=ChatMemberResponse)
def add_chat_member(
    chat_id: int,
    payload: ChatMemberAddRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = db.query(Chat).filter(Chat.id == chat_id).first()

    if not chat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat not found",
        )

    requester_membership = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == current_user.id,
        )
        .first()
    )

    if not requester_membership:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this chat",
        )

    if chat.type != "group":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You can add members only to group chats",
        )

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
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == payload.user_id,
        )
        .first()
    )

    if existing_member:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User is already a member of this chat",
        )

    new_member = ChatMember(
        chat_id=chat_id,
        user_id=payload.user_id,
        role="member",
    )

    db.add(new_member)
    db.commit()

    return ChatMemberResponse(
        id=user_to_add.id,
        username=user_to_add.username,
        email=user_to_add.email,
        role="member",
    )