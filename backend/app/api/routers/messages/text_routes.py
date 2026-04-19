from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.application.media.constants import PRIVATE_MEDIA_MESSAGE_TYPES
from app.application.messages.chat_recipients import recipient_user_ids_excluding_sender
from app.application.messages.document_rules import push_preview_for_message
from app.application.messages.inbox_delivery import notify_inbox_new_message
from app.application.messages.membership_reads import repoint_last_read_before_message_delete
from app.application.messages.message_projection import (
    build_message_payload,
    message_to_response,
    safe_message_type,
)
from app.application.messages.reply_validation import validate_reply_target
from app.application.realtime.chat_events import (
    publish_message_deleted,
    publish_message_updated,
    publish_new_message,
)
from app.core.dependencies import get_current_user
from app.core.push_service import send_chat_message_push
from app.db.database import get_db
from app.domain.policies.chat_access import require_chat_member
from app.domain.policies.message_access import (
    require_message_sender,
    require_message_sender_for_delete,
)
from app.infrastructure.storage.s3_storage import S3StorageService, is_private_s3_ready
from app.models.message import Message
from app.models.user import User
from app.schemas.message_schema import (
    ForwardMessageRequest,
    MessageCreate,
    MessageResponse,
    MessageUpdate,
)

router = APIRouter()


@router.post("/", response_model=MessageResponse)
async def send_message(
    message: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_chat_member(db, message.chat_id, current_user)
    validate_reply_target(db, message.chat_id, message.reply_to_message_id)

    new_message = Message(
        chat_id=message.chat_id,
        sender_id=current_user.id,
        text=message.text,
        message_type="text",
        media_key=None,
        media_url=None,
        media_mime_type=None,
        media_size=None,
        is_updated=False,
        reply_to_message_id=message.reply_to_message_id,
    )

    db.add(new_message)
    db.commit()
    db.refresh(new_message)

    await publish_new_message(message.chat_id, build_message_payload(new_message, db))

    recipient_user_ids = recipient_user_ids_excluding_sender(
        db, new_message.chat_id, current_user.id
    )

    sender_name = current_user.username

    try:
        send_chat_message_push(
            db=db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            recipient_user_ids=recipient_user_ids,
            message_text=new_message.text,
        )
    except Exception as e:
        print(f"Push sending skipped: {e}")

    try:
        await notify_inbox_new_message(
            db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            preview=new_message.text or "",
            recipient_user_ids=recipient_user_ids,
        )
    except Exception as e:
        print(f"Inbox notify skipped: {e}")

    return message_to_response(new_message, db, viewer_user_id=current_user.id)


@router.post("/forward", response_model=MessageResponse)
async def forward_message_endpoint(
    payload: ForwardMessageRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    src = db.query(Message).filter(Message.id == payload.source_message_id).first()
    if not src:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message not found",
        )

    require_chat_member(db, src.chat_id, current_user)
    require_chat_member(db, payload.target_chat_id, current_user)

    new_message = Message(
        chat_id=payload.target_chat_id,
        sender_id=current_user.id,
        text=src.text,
        message_type=safe_message_type(src),
        media_key=src.media_key,
        media_url=src.media_url,
        media_mime_type=src.media_mime_type,
        media_size=src.media_size,
        is_updated=False,
        reply_to_message_id=None,
        forwarded_from_user_id=src.sender_id,
    )

    db.add(new_message)
    db.commit()
    db.refresh(new_message)

    await publish_new_message(
        payload.target_chat_id,
        build_message_payload(new_message, db),
    )

    recipient_user_ids = recipient_user_ids_excluding_sender(
        db, new_message.chat_id, current_user.id
    )

    preview = push_preview_for_message(new_message)
    try:
        send_chat_message_push(
            db=db,
            chat_id=new_message.chat_id,
            sender_name=current_user.username,
            recipient_user_ids=recipient_user_ids,
            message_text=preview,
        )
    except Exception as e:
        print(f"Push sending skipped: {e}")

    try:
        await notify_inbox_new_message(
            db,
            chat_id=new_message.chat_id,
            sender_name=current_user.username,
            preview=preview,
            recipient_user_ids=recipient_user_ids,
        )
    except Exception as e:
        print(f"Inbox notify skipped: {e}")

    return message_to_response(new_message, db, viewer_user_id=current_user.id)


@router.patch("/{message_id}", response_model=MessageResponse)
async def update_message(
    message_id: int,
    message_data: MessageUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    message = db.query(Message).filter(Message.id == message_id).first()

    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message not found",
        )

    require_message_sender(message, current_user)

    if message.message_type != "text":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only text messages can be edited",
        )

    message.text = message_data.text
    message.updated_at = datetime.utcnow()
    message.is_updated = True

    db.commit()
    db.refresh(message)

    await publish_message_updated(
        message.chat_id,
        build_message_payload(message, db),
    )

    return message_to_response(message, db, viewer_user_id=current_user.id)


@router.delete("/{message_id}")
async def delete_message(
    message_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    message = db.query(Message).filter(Message.id == message_id).first()

    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message not found",
        )

    require_message_sender_for_delete(message, current_user)

    chat_id = message.chat_id
    media_key = (
        message.media_key
        if safe_message_type(message) in PRIVATE_MEDIA_MESSAGE_TYPES
        else None
    )

    repoint_last_read_before_message_delete(db, chat_id, message.id)
    db.delete(message)
    db.commit()

    if media_key and is_private_s3_ready():
        try:
            storage = S3StorageService()
            storage.delete_private_object(media_key)
        except Exception as e:
            print(f"Private media delete skipped: {e}")

    await publish_message_deleted(chat_id, message_id=message_id)

    return {"detail": "Message deleted"}
