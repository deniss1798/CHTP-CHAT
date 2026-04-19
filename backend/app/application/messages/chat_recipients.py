from sqlalchemy.orm import Session

from app.repositories.chat_member_repository import list_member_user_ids


def recipient_user_ids_excluding_sender(
    db: Session, chat_id: int, sender_user_id: int
) -> list[int]:
    return [
        uid
        for uid in list_member_user_ids(db, chat_id)
        if uid != int(sender_user_id)
    ]
