from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, case
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.user import User
from app.schemas.chat_schema import ChatCreate, ChatResponse, ChatMemberResponse,ChatDetailResponse, UserShort 

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
        if not chat_data.title:
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
                ) == len(member_ids)
            )
            .first()
        )

        if existing_chat:
            chat = db.query(Chat).filter(Chat.id == existing_chat.id).first()
            return ChatResponse(
                id=chat.id,
                type=chat.type,
                title=chat.title,
                created_by=chat.created_by,
            )

    new_chat = Chat(
        type=chat_data.type,
        title=chat_data.title,
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
        created_by=new_chat.created_by,
    )


@router.get("/")
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

    return [
        {
            "id": chat.id,
            "type": chat.type,
            "title": chat.title,
            "created_by": chat.created_by,
        }
        for chat in chats
    ]
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

    # Проверка участия
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

    other_user_data = None

    # Если private-чат — найдём второго участника
    if chat.type == "private":
        other_member = (
            db.query(User)
            .join(ChatMember, ChatMember.user_id == User.id)
            .filter(
                ChatMember.chat_id == chat_id,
                User.id != current_user.id,
            )
            .first()
        )

        if other_member:
            other_user_data = UserShort(
                id=other_member.id,
                username=other_member.username,
                email=other_member.email,
            )

    return ChatDetailResponse(
        id=chat.id,
        type=chat.type,
        title=chat.title,
        created_by=chat.created_by,
        other_user=other_user_data,
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