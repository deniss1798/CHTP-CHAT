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

    def list_latest_for_chat(self, chat_id: int, limit: int) -> list[Message]:
        """Последние [limit] сообщений по возрастанию id."""
        rows = (
            self._db.query(Message)
            .filter(Message.chat_id == chat_id)
            .order_by(Message.id.desc())
            .limit(limit)
            .all()
        )
        return list(reversed(rows))

    def list_older_than(
        self, chat_id: int, before_message_id: int, limit: int
    ) -> list[Message]:
        """Сообщения старее before_message_id (id < …), по возрастанию id."""
        rows = (
            self._db.query(Message)
            .filter(
                Message.chat_id == chat_id,
                Message.id < before_message_id,
            )
            .order_by(Message.id.desc())
            .limit(limit)
            .all()
        )
        return list(reversed(rows))

    def list_newer_than(
        self, chat_id: int, after_message_id: int, limit: int
    ) -> list[Message]:
        """Сообщения новее after_message_id (id > …), по возрастанию id."""
        return (
            self._db.query(Message)
            .filter(
                Message.chat_id == chat_id,
                Message.id > after_message_id,
            )
            .order_by(Message.id.asc())
            .limit(limit)
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
