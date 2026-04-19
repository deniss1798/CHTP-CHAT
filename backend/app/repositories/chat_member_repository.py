from sqlalchemy.orm import Session

from app.models.chat_member import ChatMember


def list_member_user_ids(db: Session, chat_id: int) -> list[int]:
    rows = (
        db.query(ChatMember.user_id)
        .filter(ChatMember.chat_id == chat_id)
        .all()
    )
    return [int(r[0]) for r in rows]
