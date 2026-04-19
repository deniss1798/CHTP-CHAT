from sqlalchemy.orm import Session

from app.models.message import Message


class MessagesRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_id(self, message_id: int) -> Message | None:
        return self._db.query(Message).filter(Message.id == message_id).first()

    def list_for_chat_ordered(self, chat_id: int) -> list[Message]:
        return (
            self._db.query(Message)
            .filter(Message.chat_id == chat_id)
            .order_by(Message.created_at.asc(), Message.id.asc())
            .all()
        )

    def list_by_ids(self, ids: list[int]) -> list[Message]:
        if not ids:
            return []
        return self._db.query(Message).filter(Message.id.in_(ids)).all()

    def add(self, message: Message) -> None:
        self._db.add(message)

    def commit_refresh(self, message: Message) -> None:
        self._db.commit()
        self._db.refresh(message)

    def commit(self) -> None:
        self._db.commit()

    def delete(self, message: Message) -> None:
        self._db.delete(message)

    def flush(self) -> None:
        self._db.flush()
