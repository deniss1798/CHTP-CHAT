from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.domain.policies.chat_access import require_chat_member
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.message import Message
from app.models.user import User
from app.schemas.chat_schema import ChatDetailResponse, UserShort


def message_type_for_chat_list(message: Message | None) -> str | None:
    if message is None:
        return None
    mt = message.message_type
    if mt is None or (isinstance(mt, str) and not mt.strip()):
        return "text"
    return str(mt)


def unread_count_for_user(db: Session, chat_id: int, user_id: int) -> int:
    member = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == user_id,
        )
        .first()
    )
    if not member:
        return 0
    last_read = int(member.last_read_message_id or 0)
    uid = int(user_id)
    cid = int(chat_id)
    return (
        db.query(Message)
        .filter(
            Message.chat_id == cid,
            Message.sender_id != uid,
            Message.id > last_read,
        )
        .count()
    )


def build_chat_detail_response(db: Session, chat_id: int, current_user: User) -> ChatDetailResponse:
    chat = db.query(Chat).filter(Chat.id == chat_id).first()

    if not chat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat not found",
        )

    require_chat_member(db, chat_id, current_user)

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
            last_seen_at=user.last_seen_at,
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
