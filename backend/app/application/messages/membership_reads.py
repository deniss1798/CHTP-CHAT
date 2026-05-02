from sqlalchemy.orm import Session

from app.models.chat_member import ChatMember
from app.models.message import Message


def repoint_last_read_before_message_delete(
    db: Session, chat_id: int, deleted_message_id: int
) -> None:
    """Иначе при SET NULL на FK счётчик непрочитанных считает все сообщения заново."""
    prev = (
        db.query(Message.id)
        .filter(Message.chat_id == chat_id, Message.id < deleted_message_id)
        .order_by(Message.id.desc())
        .first()
    )
    new_lr = prev[0] if prev else None
    (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.last_read_message_id == deleted_message_id,
        )
        .update({ChatMember.last_read_message_id: new_lr}, synchronize_session=False)
    )
