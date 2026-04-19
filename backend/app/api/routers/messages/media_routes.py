from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.application.media.constants import (
    ALLOWED_IMAGE_TYPES,
    ALLOWED_VIDEO_TYPES,
    MAX_DOCUMENT_SIZE,
    MAX_IMAGE_SIZE,
    MAX_VIDEO_SIZE,
)
from app.application.messages.chat_recipients import recipient_user_ids_excluding_sender
from app.application.messages.document_rules import (
    sanitize_document_filename,
    validate_document_file,
)
from app.application.messages.inbox_delivery import notify_inbox_new_message
from app.application.messages.message_projection import (
    build_message_payload,
    message_to_response,
    safe_message_text,
)
from app.application.messages.reply_validation import validate_reply_target
from app.application.realtime.chat_events import publish_new_message
from app.core.dependencies import get_current_user
from app.core.push_service import send_chat_message_push
from app.db.database import get_db
from app.domain.policies.chat_access import require_chat_member
from app.infrastructure.media.video_transcode import try_transcode_to_desktop_mp4
from app.infrastructure.storage.s3_storage import S3StorageService, is_private_s3_ready
from app.models.message import Message
from app.models.user import User
from app.schemas.message_schema import MessageResponse

router = APIRouter()


@router.post("/photo", response_model=MessageResponse)
async def send_photo_message(
    chat_id: int = Form(...),
    file: UploadFile = File(...),
    reply_to_message_id: int | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_chat_member(db, chat_id, current_user)
    validate_reply_target(db, chat_id, reply_to_message_id)

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

    await publish_new_message(chat_id, build_message_payload(new_message, db))

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
            message_text="📷 Фото",
        )
    except Exception as e:
        print(f"Push sending skipped: {e}")

    try:
        await notify_inbox_new_message(
            db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            preview="📷 Фото",
            recipient_user_ids=recipient_user_ids,
        )
    except Exception as e:
        print(f"Inbox notify skipped: {e}")

    return message_to_response(new_message, db, viewer_user_id=current_user.id)


@router.post("/video", response_model=MessageResponse)
async def send_video_message(
    chat_id: int = Form(...),
    file: UploadFile = File(...),
    reply_to_message_id: int | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_chat_member(db, chat_id, current_user)
    validate_reply_target(db, chat_id, reply_to_message_id)

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

    await publish_new_message(chat_id, build_message_payload(new_message, db))

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
            message_text="🎥 Видео",
        )
    except Exception as e:
        print(f"Push sending skipped: {e}")

    try:
        await notify_inbox_new_message(
            db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            preview="🎥 Видео",
            recipient_user_ids=recipient_user_ids,
        )
    except Exception as e:
        print(f"Inbox notify skipped: {e}")

    return message_to_response(new_message, db, viewer_user_id=current_user.id)


@router.post("/video-note", response_model=MessageResponse)
@router.post("/video_note", response_model=MessageResponse)
async def send_video_note_message(
    chat_id: int = Form(...),
    file: UploadFile = File(...),
    reply_to_message_id: int | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_chat_member(db, chat_id, current_user)
    validate_reply_target(db, chat_id, reply_to_message_id)

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

    await publish_new_message(chat_id, build_message_payload(new_message, db))

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
            message_text="🎬 Видеосообщение",
        )
    except Exception as e:
        print(f"Push sending skipped: {e}")

    try:
        await notify_inbox_new_message(
            db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            preview="🎬 Видеосообщение",
            recipient_user_ids=recipient_user_ids,
        )
    except Exception as e:
        print(f"Inbox notify skipped: {e}")

    return message_to_response(new_message, db, viewer_user_id=current_user.id)


@router.post("/file", response_model=MessageResponse)
@router.post("/document", response_model=MessageResponse)
async def send_document_message(
    chat_id: int = Form(...),
    file: UploadFile = File(...),
    reply_to_message_id: int | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_chat_member(db, chat_id, current_user)
    validate_reply_target(db, chat_id, reply_to_message_id)

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

    safe_name = sanitize_document_filename(file.filename)
    ext, resolved_mime = validate_document_file(file, safe_name)

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

    await publish_new_message(chat_id, build_message_payload(new_message, db))

    recipient_user_ids = recipient_user_ids_excluding_sender(
        db, new_message.chat_id, current_user.id
    )

    sender_name = current_user.username
    preview = safe_message_text(new_message).strip() or "📎 Файл"

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
        await notify_inbox_new_message(
            db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            preview=preview,
            recipient_user_ids=recipient_user_ids,
        )
    except Exception as e:
        print(f"Inbox notify skipped: {e}")

    return message_to_response(new_message, db, viewer_user_id=current_user.id)
