from sqlalchemy.orm import Session

from app.models.chat_member import ChatMember
from app.repositories.chat_member_repository import list_member_user_ids


def filter_recipients_excluding_chat_muted(
    db: Session, chat_id: int, user_ids: list[int]
) -> list[int]:
    if not user_ids:
        return []
    muted_rows = (
        db.query(ChatMember.user_id)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id.in_(user_ids),
            ChatMember.notifications_muted.is_(True),
        )
        .all()
    )
    muted = {int(r[0]) for r in muted_rows}
    return [uid for uid in user_ids if uid not in muted]


def recipient_user_ids_excluding_sender(
    db: Session, chat_id: int, sender_user_id: int
) -> list[int]:
    return [
        uid
        for uid in list_member_user_ids(db, chat_id)
        if uid != int(sender_user_id)
    ]
