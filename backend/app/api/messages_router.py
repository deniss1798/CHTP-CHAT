import os
import re
from collections.abc import Callable
from datetime import datetime

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.core.push_service import build_inbox_new_message_event, send_chat_message_push
from app.core.ws_manager import inbox_manager, manager
from app.db.database import get_db
from app.models.chat_member import ChatMember
from app.models.message import Message
from app.models.user import User
from app.schemas.message_schema import (
    ForwardMessageRequest,
    MessageCreate,
    MessageReplyPreview,
    MessageResponse,
    MessageUpdate,
)
from app.services.s3_storage import S3StorageService, is_private_s3_ready
from app.services.video_transcode import try_transcode_to_desktop_mp4

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

MAX_DOCUMENT_SIZE = 50 * 1024 * 1024  # 50 MB

# Расширение (нижний регистр, с точкой) → ожидаемый основной MIME.
# Архивы и исполняемые файлы не принимаем; .txt — только text/plain.
ALLOWED_DOCUMENT_EXTENSIONS: dict[str, str] = {
    ".pdf": "application/pdf",
    ".doc": "application/msword",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".xls": "application/vnd.ms-excel",
    ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".ppt": "application/vnd.ms-powerpoint",
    ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ".odt": "application/vnd.oasis.opendocument.text",
    ".ods": "application/vnd.oasis.opendocument.spreadsheet",
    ".odp": "application/vnd.oasis.opendocument.presentation",
    ".rtf": "application/rtf",
    ".txt": "text/plain",
}

PRIVATE_MEDIA_MESSAGE_TYPES = frozenset({"image", "video", "video_note", "document"})


async def _notify_inbox_new_message(
    db: Session,
    *,
    chat_id: int,
    sender_name: str,
    preview: str,
    recipient_user_ids: list[int],
) -> None:
    if not recipient_user_ids:
        return
    for uid in recipient_user_ids:
        payload = build_inbox_new_message_event(
            db,
            chat_id=chat_id,
            recipient_user_id=uid,
            sender_name=sender_name,
            preview=preview,
        )
        await inbox_manager.send_json(uid, payload)


def _repoint_last_read_before_message_delete(
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


def _make_s3_getter(
    storage: S3StorageService | None = None,
) -> Callable[[], S3StorageService]:
    """Создаёт S3 только при первом обращении (presigned URL для приватного медиа)."""
    if storage is not None:
        return lambda: storage
    holder: list[S3StorageService | None] = [None]

    def get() -> S3StorageService:
        if holder[0] is None:
            holder[0] = S3StorageService()
        return holder[0]

    return get


def _load_reply_parent(db: Session, reply_to_message_id: int | None) -> Message | None:
    if not reply_to_message_id:
        return None
    return db.query(Message).filter(Message.id == reply_to_message_id).first()


def _safe_message_text(message: Message) -> str:
    t = message.text
    return "" if t is None else str(t)


def _safe_message_type(message: Message) -> str:
    mt = message.message_type
    if mt is None or (isinstance(mt, str) and not mt.strip()):
        return "text"
    return str(mt)


def _reply_preview_for_parent(
    parent: Message,
    get_storage: Callable[[], S3StorageService],
) -> MessageReplyPreview:
    media_url = parent.media_url
    ptype = _safe_message_type(parent)
    if (
        is_private_s3_ready()
        and ptype in PRIVATE_MEDIA_MESSAGE_TYPES
        and parent.media_key
    ):
        media_url = get_storage().generate_private_file_url(object_key=parent.media_key)
    return MessageReplyPreview(
        id=parent.id,
        sender_id=parent.sender_id,
        text=_safe_message_text(parent),
        message_type=ptype,
        media_url=media_url,
    )


def _message_to_response(
    message: Message,
    db: Session,
    storage: S3StorageService | None = None,
    viewer_user_id: int | None = None,
) -> MessageResponse:
    get_storage = _make_s3_getter(storage)

    reply_preview: MessageReplyPreview | None = None
    if message.reply_to_message_id:
        parent = _load_reply_parent(db, message.reply_to_message_id)
        if parent:
            reply_preview = _reply_preview_for_parent(parent, get_storage)

    mtype_single = _safe_message_type(message)
    media_url = message.media_url
    if (
        is_private_s3_ready()
        and mtype_single in PRIVATE_MEDIA_MESSAGE_TYPES
        and message.media_key
    ):
        media_url = get_storage().generate_private_file_url(object_key=message.media_key)

    delivery_status = None
    if viewer_user_id is not None:
        delivery_status = _compute_delivery_status(
            db, message.chat_id, message, viewer_user_id
        )

    return MessageResponse(
        id=message.id,
        chat_id=message.chat_id,
        sender_id=message.sender_id,
        text=_safe_message_text(message),
        message_type=mtype_single,
        media_key=message.media_key,
        media_url=media_url,
        media_mime_type=message.media_mime_type,
        media_size=message.media_size,
        created_at=message.created_at,
        updated_at=message.updated_at,
        is_updated=bool(message.is_updated) if message.is_updated is not None else False,
        reply_to_message_id=message.reply_to_message_id,
        reply_to=reply_preview,
        forwarded_from_user_id=message.forwarded_from_user_id,
        delivery_status=delivery_status,
    )


def _message_to_response_batched(
    message: Message,
    parents_by_id: dict[int, Message],
    get_storage: Callable[[], S3StorageService],
    db: Session,
    viewer_user_id: int,
) -> MessageResponse:
    reply_preview: MessageReplyPreview | None = None
    if message.reply_to_message_id:
        parent = parents_by_id.get(message.reply_to_message_id)
        if parent:
            reply_preview = _reply_preview_for_parent(parent, get_storage)

    media_url = message.media_url
    mtype = _safe_message_type(message)
    if (
        is_private_s3_ready()
        and mtype in PRIVATE_MEDIA_MESSAGE_TYPES
        and message.media_key
    ):
        media_url = get_storage().generate_private_file_url(object_key=message.media_key)

    delivery_status = _compute_delivery_status(
        db, message.chat_id, message, viewer_user_id
    )

    return MessageResponse(
        id=message.id,
        chat_id=message.chat_id,
        sender_id=message.sender_id,
        text=_safe_message_text(message),
        message_type=mtype,
        media_key=message.media_key,
        media_url=media_url,
        media_mime_type=message.media_mime_type,
        media_size=message.media_size,
        created_at=message.created_at,
        updated_at=message.updated_at,
        is_updated=bool(message.is_updated) if message.is_updated is not None else False,
        reply_to_message_id=message.reply_to_message_id,
        reply_to=reply_preview,
        forwarded_from_user_id=message.forwarded_from_user_id,
        delivery_status=delivery_status,
    )


def _build_message_payload(message: Message, db: Session, storage: S3StorageService | None = None) -> dict:
    get_storage = _make_s3_getter(storage)

    reply_to_dict = None
    if message.reply_to_message_id:
        parent = _load_reply_parent(db, message.reply_to_message_id)
        if parent:
            reply_to_dict = _reply_preview_for_parent(parent, get_storage).model_dump()

    media_url = message.media_url
    mtype_payload = _safe_message_type(message)
    if (
        is_private_s3_ready()
        and mtype_payload in PRIVATE_MEDIA_MESSAGE_TYPES
        and message.media_key
    ):
        media_url = get_storage().generate_private_file_url(object_key=message.media_key)

    return {
        "id": message.id,
        "chat_id": message.chat_id,
        "sender_id": message.sender_id,
        "text": message.text,
        "message_type": mtype_payload,
        "media_key": message.media_key,
        "media_url": media_url,
        "media_mime_type": message.media_mime_type,
        "media_size": message.media_size,
        "created_at": message.created_at.isoformat() if message.created_at else None,
        "updated_at": message.updated_at.isoformat() if message.updated_at else None,
        "is_updated": message.is_updated,
        "reply_to_message_id": message.reply_to_message_id,
        "reply_to": reply_to_dict,
        "forwarded_from_user_id": message.forwarded_from_user_id,
    }


def _compute_delivery_status(
    db: Session,
    chat_id: int,
    message: Message,
    viewer_user_id: int,
) -> str | None:
    if message.sender_id != viewer_user_id:
        return None
    members = (
        db.query(ChatMember)
        .filter(ChatMember.chat_id == chat_id)
        .all()
    )
    others = [m for m in members if m.user_id != message.sender_id]
    if not others:
        return None
    for m in others:
        lr = m.last_read_message_id or 0
        if lr < message.id:
            return "sent"
    return "read"


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
    if not is_private_s3_ready():
        return messages

    get_storage = _make_s3_getter()

    for message in messages:
        mtype = _safe_message_type(message)
        if mtype in PRIVATE_MEDIA_MESSAGE_TYPES and message.media_key:
            message.media_url = get_storage().generate_private_file_url(
                object_key=message.media_key
            )

    return messages


def _apply_private_media_urls_map(messages: list[Message]) -> None:
    if not is_private_s3_ready():
        return

    get_storage = _make_s3_getter()

    for message in messages:
        mtype = _safe_message_type(message)
        if mtype in PRIVATE_MEDIA_MESSAGE_TYPES and message.media_key:
            message.media_url = get_storage().generate_private_file_url(
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

    try:
        await _notify_inbox_new_message(
            db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            preview=new_message.text or "",
            recipient_user_ids=recipient_user_ids,
        )
    except Exception as e:
        print(f"Inbox notify skipped: {e}")

    return _message_to_response(new_message, db, viewer_user_id=current_user.id)


def _push_preview_for_message(message: Message) -> str:
    t = _safe_message_text(message).strip()
    if t:
        return t
    mt = _safe_message_type(message)
    if mt == "image":
        return "📷 Фото"
    if mt == "video":
        return "🎥 Видео"
    if mt == "video_note":
        return "🎥 Видеосообщение"
    if mt == "document":
        return "📎 Файл"
    return "Новое сообщение"


def _sanitize_document_filename(name: str | None) -> str:
    if not name:
        return "file"
    base = os.path.basename(str(name).replace("\\", "/"))
    base = base.strip() or "file"
    base = re.sub(r"[\x00-\x1f\x7f]", "", base)
    base = re.sub(r'[^a-zA-Z0-9._\-() \u0400-\u04FF]', "_", base)
    if len(base) > 200:
        root, ext = os.path.splitext(base)
        base = root[:180] + ext
    return base or "file"


def _validate_document_file(
    upload: UploadFile,
    sanitized_name: str,
) -> tuple[str, str]:
    ext = os.path.splitext(sanitized_name)[1].lower()
    if ext not in ALLOWED_DOCUMENT_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File type not allowed",
        )
    expected_mime = ALLOWED_DOCUMENT_EXTENSIONS[ext]
    ct_raw = (upload.content_type or "").split(";")[0].strip().lower()
    if not ct_raw or ct_raw == "application/octet-stream":
        return ext, expected_mime
    if ct_raw == expected_mime:
        return ext, expected_mime
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Content-type does not match file extension",
    )


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

    _ensure_chat_member(src.chat_id, current_user.id, db)
    _ensure_chat_member(payload.target_chat_id, current_user.id, db)

    new_message = Message(
        chat_id=payload.target_chat_id,
        sender_id=current_user.id,
        text=src.text,
        message_type=_safe_message_type(src),
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

    await manager.broadcast(
        payload.target_chat_id,
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

    preview = _push_preview_for_message(new_message)
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
        await _notify_inbox_new_message(
            db,
            chat_id=new_message.chat_id,
            sender_name=current_user.username,
            preview=preview,
            recipient_user_ids=recipient_user_ids,
        )
    except Exception as e:
        print(f"Inbox notify skipped: {e}")

    return _message_to_response(new_message, db, viewer_user_id=current_user.id)


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

    if not is_private_s3_ready():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Private S3 is not configured. Set S3_ENDPOINT_URL, "
                "S3_ACCESS_KEY_ID (or AWS_ACCESS_KEY_ID), "
                "S3_SECRET_ACCESS_KEY (or AWS_SECRET_ACCESS_KEY), "
                "S3_PRIVATE_BUCKET in .env"
            ),
        )

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

    try:
        await _notify_inbox_new_message(
            db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            preview="📷 Фото",
            recipient_user_ids=recipient_user_ids,
        )
    except Exception as e:
        print(f"Inbox notify skipped: {e}")

    return _message_to_response(new_message, db, viewer_user_id=current_user.id)


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

    if not is_private_s3_ready():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Private S3 is not configured. Set S3_ENDPOINT_URL, "
                "S3_ACCESS_KEY_ID (or AWS_ACCESS_KEY_ID), "
                "S3_SECRET_ACCESS_KEY (or AWS_SECRET_ACCESS_KEY), "
                "S3_PRIVATE_BUCKET in .env"
            ),
        )

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

    transcoded = try_transcode_to_desktop_mp4(content)
    if transcoded is not None:
        content = transcoded
        extension = ".mp4"
        media_content_type = "video/mp4"
    else:
        media_content_type = video_content_type or "application/octet-stream"

    storage = S3StorageService()

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

    try:
        await _notify_inbox_new_message(
            db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            preview="🎥 Видео",
            recipient_user_ids=recipient_user_ids,
        )
    except Exception as e:
        print(f"Inbox notify skipped: {e}")

    return _message_to_response(new_message, db, viewer_user_id=current_user.id)


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

    if not is_private_s3_ready():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Private S3 is not configured. Set S3_ENDPOINT_URL, "
                "S3_ACCESS_KEY_ID (or AWS_ACCESS_KEY_ID), "
                "S3_SECRET_ACCESS_KEY (or AWS_SECRET_ACCESS_KEY), "
                "S3_PRIVATE_BUCKET in .env"
            ),
        )

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

    transcoded = try_transcode_to_desktop_mp4(content)
    if transcoded is not None:
        content = transcoded
        extension = ".mp4"
        media_content_type = "video/mp4"
    else:
        media_content_type = video_content_type or "application/octet-stream"

    storage = S3StorageService()

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

    try:
        await _notify_inbox_new_message(
            db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            preview="🎬 Видеосообщение",
            recipient_user_ids=recipient_user_ids,
        )
    except Exception as e:
        print(f"Inbox notify skipped: {e}")

    return _message_to_response(new_message, db, viewer_user_id=current_user.id)


@router.post("/file", response_model=MessageResponse)
@router.post("/document", response_model=MessageResponse)
async def send_document_message(
    chat_id: int = Form(...),
    file: UploadFile = File(...),
    reply_to_message_id: int | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Документы: allowlist расширений, без архивов/исполняемых, до 50 МБ. Дублирующий путь: POST /file."""
    _ensure_chat_member(chat_id, current_user.id, db)
    _validate_reply_target(db, chat_id, reply_to_message_id)

    if not is_private_s3_ready():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Private S3 is not configured. Set S3_ENDPOINT_URL, "
                "S3_ACCESS_KEY_ID (or AWS_ACCESS_KEY_ID), "
                "S3_SECRET_ACCESS_KEY (or AWS_SECRET_ACCESS_KEY), "
                "S3_PRIVATE_BUCKET in .env"
            ),
        )

    safe_name = _sanitize_document_filename(file.filename)
    ext, resolved_mime = _validate_document_file(file, safe_name)

    content = await file.read()
    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty file",
        )
    if len(content) > MAX_DOCUMENT_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File is too large. Max size is 50 MB",
        )

    storage = S3StorageService()
    media_key, media_url = storage.upload_private_message_document(
        content=content,
        chat_id=chat_id,
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
    preview = _safe_message_text(new_message).strip() or "📎 Файл"

    try:
        send_chat_message_push(
            db=db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            recipient_user_ids=recipient_user_ids,
            message_text=preview,
        )
    except Exception as e:
        print(f"Push sending skipped: {e}")

    try:
        await _notify_inbox_new_message(
            db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            preview=preview,
            recipient_user_ids=recipient_user_ids,
        )
    except Exception as e:
        print(f"Inbox notify skipped: {e}")

    return _message_to_response(new_message, db, viewer_user_id=current_user.id)


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

    return _message_to_response(message, db, viewer_user_id=current_user.id)


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

    _repoint_last_read_before_message_delete(db, chat_id, message.id)
    db.delete(message)
    db.commit()

    if media_key and is_private_s3_ready():
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

    get_storage = _make_s3_getter()

    return [
        _message_to_response_batched(
            message, parents_by_id, get_storage, db, current_user.id
        )
        for message in messages
    ]
