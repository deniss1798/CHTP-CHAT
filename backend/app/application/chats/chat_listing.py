from datetime import datetime

from sqlalchemy.orm import Session

from app.application.chats.chat_queries import message_type_for_chat_list, unread_count_for_user
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.message import Message
from app.models.user import User
from app.schemas.chat_schema import ChatResponse


def list_my_chats(db: Session, current_user: User) -> list[ChatResponse]:
    chats = (
        db.query(Chat)
        .join(ChatMember, ChatMember.chat_id == Chat.id)
        .filter(ChatMember.user_id == current_user.id)
        .order_by(Chat.id.desc())
        .all()
    )

    result: list[ChatResponse] = []

    for chat in chats:
        chat_title = chat.title
        chat_avatar_url = chat.avatar_url

        users = (
            db.query(User)
            .join(ChatMember, ChatMember.user_id == User.id)
            .filter(ChatMember.chat_id == chat.id)
            .order_by(User.username.asc())
            .all()
        )

        peer_last_seen_at = None
        if chat.type == "private":
            other_user = next((user for user in users if user.id != current_user.id), None)
            if other_user:
                chat_title = other_user.username
                chat_avatar_url = other_user.avatar_url
                peer_last_seen_at = other_user.last_seen_at

        last_message = (
            db.query(Message)
            .filter(Message.chat_id == chat.id)
            .order_by(Message.created_at.desc(), Message.id.desc())
            .first()
        )

        membership = (
            db.query(ChatMember)
            .filter(
                ChatMember.chat_id == chat.id,
                ChatMember.user_id == current_user.id,
            )
            .first()
        )
        my_last_read = (membership.last_read_message_id or 0) if membership else 0

        result.append(
            ChatResponse(
                id=chat.id,
                type=chat.type,
                title=chat_title,
                avatar_url=chat_avatar_url,
                created_by=chat.created_by,
                last_message=last_message.text if last_message else None,
                last_message_type=message_type_for_chat_list(last_message),
                last_message_at=last_message.created_at if last_message else None,
                last_message_sender_id=last_message.sender_id if last_message else None,
                last_message_id=last_message.id if last_message else None,
                my_last_read_message_id=my_last_read,
                unread_count=unread_count_for_user(db, chat.id, current_user.id),
                peer_last_seen_at=peer_last_seen_at,
            )
        )

    result.sort(
        key=lambda item: item.last_message_at or datetime.min,
        reverse=True,
    )

    return result
