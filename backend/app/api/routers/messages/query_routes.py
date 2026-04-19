from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.application.messages.message_projection import (
    apply_private_media_urls,
    apply_private_media_urls_map,
    make_s3_getter,
    message_to_response_batched,
)
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.domain.policies.chat_access import require_chat_member
from app.models.message import Message
from app.models.user import User
from app.schemas.message_schema import MessageResponse

router = APIRouter()


@router.get("/chat/{chat_id}", response_model=list[MessageResponse])
def get_chat_messages(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_chat_member(db, chat_id, current_user)

    messages = (
        db.query(Message)
        .filter(Message.chat_id == chat_id)
        .order_by(Message.created_at.asc(), Message.id.asc())
        .all()
    )

    messages = apply_private_media_urls(messages)

    reply_ids = [m.reply_to_message_id for m in messages if m.reply_to_message_id]
    parents_by_id: dict[int, Message] = {}

    if reply_ids:
        parents = db.query(Message).filter(Message.id.in_(reply_ids)).all()
        apply_private_media_urls_map(parents)
        for parent in parents:
            parents_by_id[parent.id] = parent

    get_storage = make_s3_getter()

    return [
        message_to_response_batched(
            message, parents_by_id, get_storage, db, current_user.id
        )
        for message in messages
    ]
