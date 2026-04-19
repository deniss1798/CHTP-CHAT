from datetime import datetime

from fastapi import HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.application.media.constants import PRIVATE_MEDIA_MESSAGE_TYPES
from app.application.messages.chat_recipients import recipient_user_ids_excluding_sender
from app.application.messages.document_rules import push_preview_for_message
from app.application.messages.membership_reads import repoint_last_read_before_message_delete
from app.application.messages.message_projection import (
    build_message_payload,
    message_to_response,
    safe_message_text,
    safe_message_type,
)
from app.application.messages.reply_validation import validate_reply_target
from app.domain.policies.chat_access import require_chat_member
from app.domain.policies.message_access import (
    require_message_sender,
    require_message_sender_for_delete,
)
from app.models.message import Message
from app.models.user import User
from app.repositories.messages_repository import MessagesRepository
from app.schemas.message_schema import (
    ForwardMessageRequest,
    MessageCreate,
    MessageResponse,
    MessageUpdate,
)
from app.services import media_service as media_svc
from app.services import push_service as push_svc
from app.services import ws_service


async def _notify_new_message(
    db: Session,
    *,
    new_message: Message,
    current_user: User,
    preview: str,
) -> None:
    await ws_service.broadcast_new_message(
        new_message.chat_id,
        build_message_payload(new_message, db),
    )
    recipient_user_ids = recipient_user_ids_excluding_sender(
        db,
        new_message.chat_id,
        current_user.id,
    )
    sender_name = current_user.username
    push_svc.try_send_chat_message_push(
        db=db,
        chat_id=new_message.chat_id,
        sender_name=sender_name,
        recipient_user_ids=recipient_user_ids,
        message_text=preview,
    )
    await push_svc.try_notify_inbox_new_message(
        db=db,
        chat_id=new_message.chat_id,
        sender_name=sender_name,
        preview=preview,
        recipient_user_ids=recipient_user_ids,
    )


async def send_text_message(
    db: Session,
    *,
    current_user: User,
    payload: MessageCreate,
) -> MessageResponse:
    repo = MessagesRepository(db)
    require_chat_member(db, payload.chat_id, current_user)
    validate_reply_target(db, payload.chat_id, payload.reply_to_message_id)

    new_message = Message(
        chat_id=payload.chat_id,
        sender_id=current_user.id,
        text=payload.text,
        message_type="text",
        media_key=None,
        media_url=None,
        media_mime_type=None,
        media_size=None,
        is_updated=False,
        reply_to_message_id=payload.reply_to_message_id,
    )
    repo.add(new_message)
    repo.commit_refresh(new_message)

    await _notify_new_message(
        db,
        new_message=new_message,
        current_user=current_user,
        preview=new_message.text or "",
    )

    return message_to_response(new_message, db, viewer_user_id=current_user.id)


async def forward_message(
    db: Session,
    *,
    current_user: User,
    payload: ForwardMessageRequest,
) -> MessageResponse:
    repo = MessagesRepository(db)
    src = repo.get_by_id(payload.source_message_id)
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
    repo.add(new_message)
    repo.commit_refresh(new_message)

    preview = push_preview_for_message(new_message)
    await _notify_new_message(
        db,
        new_message=new_message,
        current_user=current_user,
        preview=preview,
    )

    return message_to_response(new_message, db, viewer_user_id=current_user.id)


async def update_text_message(
    db: Session,
    *,
    current_user: User,
    message_id: int,
    payload: MessageUpdate,
) -> MessageResponse:
    repo = MessagesRepository(db)
    message = repo.get_by_id(message_id)
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

    message.text = payload.text
    message.updated_at = datetime.utcnow()
    message.is_updated = True

    repo.commit_refresh(message)

    await ws_service.broadcast_message_updated(
        message.chat_id,
        build_message_payload(message, db),
    )

    return message_to_response(message, db, viewer_user_id=current_user.id)


async def delete_message(
    db: Session,
    *,
    current_user: User,
    message_id: int,
) -> dict[str, str]:
    repo = MessagesRepository(db)
    message = repo.get_by_id(message_id)
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
    repo.delete(message)
    repo.commit()

    media_svc.delete_private_media_key(media_key)

    await ws_service.broadcast_message_deleted(chat_id, message_id=message_id)

    return {"detail": "Message deleted"}


async def send_photo_message(
    db: Session,
    *,
    current_user: User,
    chat_id: int,
    file: UploadFile,
    reply_to_message_id: int | None,
) -> MessageResponse:
    repo = MessagesRepository(db)
    require_chat_member(db, chat_id, current_user)
    validate_reply_target(db, chat_id, reply_to_message_id)
    media_svc.require_private_s3_or_503()

    content, content_type = await media_svc.read_and_validate_photo(file)
    media_key, media_url = media_svc.upload_private_message_image(
        chat_id=chat_id,
        content=content,
        content_type=content_type,
    )

    new_message = Message(
        chat_id=chat_id,
        sender_id=current_user.id,
        text="",
        message_type="image",
        media_key=media_key,
        media_url=media_url,
        media_mime_type=content_type,
        media_size=len(content),
        is_updated=False,
        reply_to_message_id=reply_to_message_id,
    )
    repo.add(new_message)
    repo.commit_refresh(new_message)
    new_message.media_url = media_svc.presign_media_url(new_message.media_key)

    await _notify_new_message(
        db,
        new_message=new_message,
        current_user=current_user,
        preview="Фото",
    )

    return message_to_response(new_message, db, viewer_user_id=current_user.id)


async def send_video_message(
    db: Session,
    *,
    current_user: User,
    chat_id: int,
    file: UploadFile,
    reply_to_message_id: int | None,
) -> MessageResponse:
    repo = MessagesRepository(db)
    require_chat_member(db, chat_id, current_user)
    validate_reply_target(db, chat_id, reply_to_message_id)
    media_svc.require_private_s3_or_503()

    content, extension, media_content_type = await media_svc.read_and_prepare_video(
        file
    )
    media_key, media_url = media_svc.upload_private_message_video(
        chat_id=chat_id,
        content=content,
        extension=extension,
        content_type=media_content_type,
    )

    new_message = Message(
        chat_id=chat_id,
        sender_id=current_user.id,
        text="",
        message_type="video",
        media_key=media_key,
        media_url=media_url,
        media_mime_type=media_content_type,
        media_size=len(content),
        is_updated=False,
        reply_to_message_id=reply_to_message_id,
    )
    repo.add(new_message)
    repo.commit_refresh(new_message)
    new_message.media_url = media_svc.presign_media_url(new_message.media_key)

    await _notify_new_message(
        db,
        new_message=new_message,
        current_user=current_user,
        preview="Видео",
    )

    return message_to_response(new_message, db, viewer_user_id=current_user.id)


async def send_video_note_message(
    db: Session,
    *,
    current_user: User,
    chat_id: int,
    file: UploadFile,
    reply_to_message_id: int | None,
) -> MessageResponse:
    repo = MessagesRepository(db)
    require_chat_member(db, chat_id, current_user)
    validate_reply_target(db, chat_id, reply_to_message_id)
    media_svc.require_private_s3_or_503()

    content, extension, media_content_type = await media_svc.read_and_prepare_video(
        file
    )
    media_key, media_url = media_svc.upload_private_message_video_note(
        chat_id=chat_id,
        content=content,
        extension=extension,
        content_type=media_content_type,
    )

    new_message = Message(
        chat_id=chat_id,
        sender_id=current_user.id,
        text="",
        message_type="video_note",
        media_key=media_key,
        media_url=media_url,
        media_mime_type=media_content_type,
        media_size=len(content),
        is_updated=False,
        reply_to_message_id=reply_to_message_id,
    )
    repo.add(new_message)
    repo.commit_refresh(new_message)
    new_message.media_url = media_svc.presign_media_url(new_message.media_key)

    await _notify_new_message(
        db,
        new_message=new_message,
        current_user=current_user,
        preview="Видеосообщение",
    )

    return message_to_response(new_message, db, viewer_user_id=current_user.id)


async def send_document_message(
    db: Session,
    *,
    current_user: User,
    chat_id: int,
    file: UploadFile,
    reply_to_message_id: int | None,
) -> MessageResponse:
    repo = MessagesRepository(db)
    require_chat_member(db, chat_id, current_user)
    validate_reply_target(db, chat_id, reply_to_message_id)
    media_svc.require_private_s3_or_503()

    content, safe_name, ext, resolved_mime = await media_svc.read_and_validate_document(
        file
    )
    media_key, media_url = media_svc.upload_private_message_document(
        chat_id=chat_id,
        content=content,
        extension=ext,
        content_type=resolved_mime,
    )

    new_message = Message(
        chat_id=chat_id,
        sender_id=current_user.id,
        text=safe_name,
        message_type="document",
        media_key=media_key,
        media_url=media_url,
        media_mime_type=resolved_mime,
        media_size=len(content),
        is_updated=False,
        reply_to_message_id=reply_to_message_id,
    )
    repo.add(new_message)
    repo.commit_refresh(new_message)
    new_message.media_url = media_svc.presign_media_url(new_message.media_key)

    preview = safe_message_text(new_message).strip() or "Файл"
    await _notify_new_message(
        db,
        new_message=new_message,
        current_user=current_user,
        preview=preview,
    )

    return message_to_response(new_message, db, viewer_user_id=current_user.id)
