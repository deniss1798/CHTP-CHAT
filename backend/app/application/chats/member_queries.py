from sqlalchemy.orm import Session

from app.domain.policies.chat_access import require_chat_member
from app.models.chat_member import ChatMember
from app.models.user import User
from app.schemas.chat_schema import ChatMemberResponse, MemberReadState


def list_chat_members(
    db: Session,
    *,
    chat_id: int,
    current_user: User,
) -> list[ChatMemberResponse]:
    require_chat_member(db, chat_id, current_user)

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
            avatar_url=user.avatar_url,
            role=role,
            last_seen_at=user.last_seen_at,
        )
        for user, role in members
    ]


def list_chat_read_state(
    db: Session,
    *,
    chat_id: int,
    current_user: User,
) -> list[MemberReadState]:
    require_chat_member(db, chat_id, current_user)

    rows = (
        db.query(ChatMember.user_id, ChatMember.last_read_message_id)
        .filter(ChatMember.chat_id == chat_id)
        .all()
    )

    return [
        MemberReadState(user_id=user_id, last_read_message_id=last_read_message_id)
        for user_id, last_read_message_id in rows
    ]
