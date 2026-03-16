from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.user import User
from app.schemas.chat_schema import ChatCreate, ChatResponse

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

    all_member_ids = set(chat_data.member_ids)
    all_member_ids.add(current_user.id)

    users_count = db.query(User).filter(User.id.in_(all_member_ids)).count()
    if users_count != len(all_member_ids):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="One or more users do not exist",
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