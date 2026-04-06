from datetime import datetime

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.core.push_service import send_chat_message_push
from app.core.ws_manager import manager
from app.db.database import get_db
from app.models.chat_member import ChatMember
from app.models.message import Message
from app.models.user import User
from app.schemas.message_schema import MessageCreate, MessageReplyPreview, MessageResponse, MessageUpdate
from app.services.s3_storage import S3StorageService

router = APIRouter(prefix="/messages", tags=["Messages"])

ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}

MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10 MB

ALLOWED_VIDEO_TYPES = {
    "video/mp4": ".mp4",
    "video/webm": ".webm",
    "video/quicktime": ".mov",
    # Часто с камеры Android
    "video/3gpp": ".3gp",
    "video/3gp": ".3gp",
}

MAX_VIDEO_SIZE = 50 * 1024 * 1024  # 50 MB

PRIVATE_MEDIA_MESSAGE_TYPES = frozenset({"image", "video", "video_note"})


def _load_reply_parent(db: Session, reply_to_message_id: int | None) -> Message | None:
    if not reply_to_message_id:
        return None
    return db.query(Message).filter(Message.id == reply_to_message_id).first()


def _reply_preview_for_parent(parent: Message, storage: S3StorageService) -> MessageReplyPreview:
    media_url = parent.media_url
    if parent.message_type in PRIVATE_MEDIA_MESSAGE_TYPES and parent.media_key:
        media_url = storage.generate_private_file_url(object_key=parent.media_key)
    return MessageReplyPreview(
        id=parent.id,
        sender_id=parent.sender_id,
        text=parent.text or "",
        message_type=parent.message_type,
        media_url=media_url,
    )


def _message_to_response(message: Message, db: Session, storage: S3StorageService | None = None) -> MessageResponse:
    if storage is None:
        storage = S3StorageService()

    reply_preview: MessageReplyPreview | None = None
    if message.reply_to_message_id:
        parent = _load_reply_parent(db, message.reply_to_message_id)
        if parent:
            reply_preview = _reply_preview_for_parent(parent, storage)

    media_url = message.media_url
    if message.message_type in PRIVATE_MEDIA_MESSAGE_TYPES and message.media_key:
        media_url = storage.generate_private_file_url(object_key=message.media_key)

    return MessageResponse(
        id=message.id,
        chat_id=message.chat_id,
        sender_id=message.sender_id,
        text=message.text,
        message_type=message.message_type,
        media_key=message.media_key,
        media_url=media_url,
        media_mime_type=message.media_mime_type,
        media_size=message.media_size,
        created_at=message.created_at,
        updated_at=message.updated_at,
        is_updated=message.is_updated,
        reply_to_message_id=message.reply_to_message_id,
        reply_to=reply_preview,
    )


def _message_to_response_batched(
    message: Message,
    parents_by_id: dict[int, Message],
    storage: S3StorageService,
) -> MessageResponse:
    reply_preview: MessageReplyPreview | None = None
    if message.reply_to_message_id:
        parent = parents_by_id.get(message.reply_to_message_id)
        if parent:
            reply_preview = _reply_preview_for_parent(parent, storage)

    media_url = message.media_url
    if message.message_type in PRIVATE_MEDIA_MESSAGE_TYPES and message.media_key:
        media_url = storage.generate_private_file_url(object_key=message.media_key)

    return MessageResponse(
        id=message.id,
        chat_id=message.chat_id,
        sender_id=message.sender_id,
        text=message.text,
        message_type=message.message_type,
        media_key=message.media_key,
        media_url=media_url,
        media_mime_type=message.media_mime_type,
        media_size=message.media_size,
        created_at=message.created_at,
        updated_at=message.updated_at,
        is_updated=message.is_updated,
        reply_to_message_id=message.reply_to_message_id,
        reply_to=reply_preview,
    )


def _build_message_payload(message: Message, db: Session, storage: S3StorageService | None = None) -> dict:
    if storage is None:
        storage = S3StorageService()

    reply_to_dict = None
    if message.reply_to_message_id:
        parent = _load_reply_parent(db, message.reply_to_message_id)
        if parent:
            reply_to_dict = _reply_preview_for_parent(parent, storage).model_dump()

    media_url = message.media_url
    if message.message_type in PRIVATE_MEDIA_MESSAGE_TYPES and message.media_key:
        media_url = storage.generate_private_file_url(object_key=message.media_key)

    return {
        "id": message.id,
        "chat_id": message.chat_id,
        "sender_id": message.sender_id,
        "text": message.text,
        "message_type": message.message_type,
        "media_key": message.media_key,
        "media_url": media_url,
        "media_mime_type": message.media_mime_type,
        "media_size": message.media_size,
        "created_at": message.created_at.isoformat() if message.created_at else None,
        "updated_at": message.updated_at.isoformat() if message.updated_at else None,
        "is_updated": message.is_updated,
        "reply_to_message_id": message.reply_to_message_id,
        "reply_to": reply_to_dict,
    }


def _ensure_chat_member(chat_id: int, user_id: int, db: Session) -> None:
    member = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == user_id,
        )
        .first()
    )

    if not member:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this chat",
        )


def _validate_reply_target(db: Session, chat_id: int, reply_to_message_id: int | None) -> None:
    if reply_to_message_id is None:
        return

    parent = db.query(Message).filter(Message.id == reply_to_message_id).first()

    if not parent or parent.chat_id != chat_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid reply target",
        )


def _apply_private_media_urls(messages: list[Message]) -> list[Message]:
    storage = S3StorageService()

    for message in messages:
        if message.message_type in PRIVATE_MEDIA_MESSAGE_TYPES and message.media_key:
            message.media_url = storage.generate_private_file_url(
                object_key=message.media_key
            )

    return messages


def _apply_private_media_urls_map(messages: list[Message]) -> None:
    storage = S3StorageService()

    for message in messages:
        if message.message_type in PRIVATE_MEDIA_MESSAGE_TYPES and message.media_key:
            message.media_url = storage.generate_private_file_url(
                object_key=message.media_key
            )


@router.post("/", response_model=MessageResponse)
async def send_message(
    message: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_chat_member(message.chat_id, current_user.id, db)
    _validate_reply_target(db, message.chat_id, message.reply_to_message_id)

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

    await manager.broadcast(
        message.chat_id,
        {
            "type": "new_message",
            "message": _build_message_payload(new_message, db),
        },
    )

    recipient_user_ids = [
        row.user_id
        for row in db.query(ChatMember)
        .filter(ChatMember.chat_id == new_message.chat_id)
        .all()
        if row.user_id != current_user.id
    ]

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

    return _message_to_response(new_message, db)


@router.post("/photo", response_model=MessageResponse)
async def send_photo_message(
    chat_id: int = Form(...),
    file: UploadFile = File(...),
    reply_to_message_id: int | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_chat_member(chat_id, current_user.id, db)
    _validate_reply_target(db, chat_id, reply_to_message_id)

    if not file.content_type or file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPG, PNG and WEBP images are allowed",
        )

    content = await file.read()

    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty file",
        )

    if len(content) > MAX_IMAGE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File is too large. Max size is 10 MB",
        )

    storage = S3StorageService()
    extension = ALLOWED_IMAGE_TYPES[file.content_type]

    media_key, media_url = storage.upload_private_message_image(
        content=content,
        chat_id=chat_id,
        extension=extension,
        content_type=file.content_type,
    )

    new_message = Message(
        chat_id=chat_id,
        sender_id=current_user.id,
        text="",
        message_type="image",
        media_key=media_key,
        media_url=media_url,
        media_mime_type=file.content_type,
        media_size=len(content),
        is_updated=False,
        reply_to_message_id=reply_to_message_id,
    )

    db.add(new_message)
    db.commit()
    db.refresh(new_message)

    new_message.media_url = storage.generate_private_file_url(
        object_key=new_message.media_key
    )

    await manager.broadcast(
        chat_id,
        {
            "type": "new_message",
            "message": _build_message_payload(new_message, db),
        },
    )

    recipient_user_ids = [
        row.user_id
        for row in db.query(ChatMember)
        .filter(ChatMember.chat_id == new_message.chat_id)
        .all()
        if row.user_id != current_user.id
    ]

    sender_name = current_user.username

    try:
        send_chat_message_push(
            db=db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            recipient_user_ids=recipient_user_ids,
            message_text="📷 Фото",
        )
    except Exception as e:
        print(f"Push sending skipped: {e}")

    return _message_to_response(new_message, db)


@router.post("/video", response_model=MessageResponse)
async def send_video_message(
    chat_id: int = Form(...),
    file: UploadFile = File(...),
    reply_to_message_id: int | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_chat_member(chat_id, current_user.id, db)
    _validate_reply_target(db, chat_id, reply_to_message_id)

    video_content_type = file.content_type
    extension: str | None = None
    if video_content_type in ALLOWED_VIDEO_TYPES:
        extension = ALLOWED_VIDEO_TYPES[video_content_type]
    else:
        # Some mobile clients may omit Content-Type; infer from filename.
        lower_name = (file.filename or "").lower()
        if lower_name.endswith(".mp4"):
            extension = ".mp4"
        elif lower_name.endswith(".webm"):
            extension = ".webm"
        elif lower_name.endswith(".mov"):
            extension = ".mov"
        elif lower_name.endswith(".3gp"):
            extension = ".3gp"

        if extension is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only MP4, WEBM, MOV and 3GP videos are allowed",
            )

    content = await file.read()

    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty file",
        )

    if len(content) > MAX_VIDEO_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File is too large. Max size is 50 MB",
        )

    storage = S3StorageService()
    media_content_type = video_content_type or "application/octet-stream"

    media_key, media_url = storage.upload_private_message_video(
        content=content,
        chat_id=chat_id,
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

    db.add(new_message)
    db.commit()
    db.refresh(new_message)

    new_message.media_url = storage.generate_private_file_url(
        object_key=new_message.media_key
    )

    await manager.broadcast(
        chat_id,
        {
            "type": "new_message",
            "message": _build_message_payload(new_message, db),
        },
    )

    recipient_user_ids = [
        row.user_id
        for row in db.query(ChatMember)
        .filter(ChatMember.chat_id == new_message.chat_id)
        .all()
        if row.user_id != current_user.id
    ]

    sender_name = current_user.username

    try:
        send_chat_message_push(
            db=db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            recipient_user_ids=recipient_user_ids,
            message_text="🎥 Видео",
        )
    except Exception as e:
        print(f"Push sending skipped: {e}")

    return _message_to_response(new_message, db)


@router.post("/video-note", response_model=MessageResponse)
@router.post("/video_note", response_model=MessageResponse)
async def send_video_note_message(
    chat_id: int = Form(...),
    file: UploadFile = File(...),
    reply_to_message_id: int | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Круглое видеосообщение (аналог Telegram video message / video note)."""
    _ensure_chat_member(chat_id, current_user.id, db)
    _validate_reply_target(db, chat_id, reply_to_message_id)

    video_content_type = file.content_type
    extension: str | None = None
    if video_content_type in ALLOWED_VIDEO_TYPES:
        extension = ALLOWED_VIDEO_TYPES[video_content_type]
    else:
        lower_name = (file.filename or "").lower()
        if lower_name.endswith(".mp4"):
            extension = ".mp4"
        elif lower_name.endswith(".webm"):
            extension = ".webm"
        elif lower_name.endswith(".mov"):
            extension = ".mov"
        elif lower_name.endswith(".3gp"):
            extension = ".3gp"

        if extension is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only MP4, WEBM, MOV and 3GP videos are allowed",
            )

    content = await file.read()

    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty file",
        )

    if len(content) > MAX_VIDEO_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File is too large. Max size is 50 MB",
        )

    storage = S3StorageService()
    media_content_type = video_content_type or "application/octet-stream"

    media_key, media_url = storage.upload_private_message_video_note(
        content=content,
        chat_id=chat_id,
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

    db.add(new_message)
    db.commit()
    db.refresh(new_message)

    new_message.media_url = storage.generate_private_file_url(
        object_key=new_message.media_key
    )

    await manager.broadcast(
        chat_id,
        {
            "type": "new_message",
            "message": _build_message_payload(new_message, db),
        },
    )

    recipient_user_ids = [
        row.user_id
        for row in db.query(ChatMember)
        .filter(ChatMember.chat_id == new_message.chat_id)
        .all()
        if row.user_id != current_user.id
    ]

    sender_name = current_user.username

    try:
        send_chat_message_push(
            db=db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            recipient_user_ids=recipient_user_ids,
            message_text="🎬 Видеосообщение",
        )
    except Exception as e:
        print(f"Push sending skipped: {e}")

    return _message_to_response(new_message, db)


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

    if message.sender_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can edit only your own messages",
        )

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

    await manager.broadcast(
        message.chat_id,
        {
            "event": "message_updated",
            "message": _build_message_payload(message, db),
        },
    )

    return _message_to_response(message, db)


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

    if message.sender_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can delete only your own messages",
        )

    chat_id = message.chat_id
    media_key = (
        message.media_key if message.message_type in PRIVATE_MEDIA_MESSAGE_TYPES else None
    )

    db.delete(message)
    db.commit()

    if media_key:
        try:
            storage = S3StorageService()
            storage.delete_private_object(media_key)
        except Exception as e:
            print(f"Private media delete skipped: {e}")

    await manager.broadcast(
        chat_id,
        {
            "event": "message_deleted",
            "id": message_id,
            "chat_id": chat_id,
        },
    )

    return {"detail": "Message deleted"}


@router.get("/chat/{chat_id}", response_model=list[MessageResponse])
def get_chat_messages(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_chat_member(chat_id, current_user.id, db)

    messages = (
        db.query(Message)
        .filter(Message.chat_id == chat_id)
        .order_by(Message.created_at.asc(), Message.id.asc())
        .all()
    )

    messages = _apply_private_media_urls(messages)

    reply_ids = [m.reply_to_message_id for m in messages if m.reply_to_message_id]
    parents_by_id: dict[int, Message] = {}

    if reply_ids:
        parents = db.query(Message).filter(Message.id.in_(reply_ids)).all()
        _apply_private_media_urls_map(parents)
        for parent in parents:
            parents_by_id[parent.id] = parent

    storage = S3StorageService()

    return [
        _message_to_response_batched(message, parents_by_id, storage)
        for message in messages
    ]
