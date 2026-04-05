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
from app.schemas.message_schema import MessageCreate, MessageResponse, MessageUpdate
from app.services.s3_storage import S3StorageService

router = APIRouter(prefix="/messages", tags=["Messages"])

ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}

MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10 MB


def _build_message_payload(message: Message) -> dict:
    return {
        "id": message.id,
        "chat_id": message.chat_id,
        "sender_id": message.sender_id,
        "text": message.text,
        "message_type": message.message_type,
        "media_key": message.media_key,
        "media_url": message.media_url,
        "media_mime_type": message.media_mime_type,
        "media_size": message.media_size,
        "created_at": message.created_at.isoformat() if message.created_at else None,
        "updated_at": message.updated_at.isoformat() if message.updated_at else None,
        "is_updated": message.is_updated,
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


def _apply_private_media_urls(messages: list[Message]) -> list[Message]:
    storage = S3StorageService()

    for message in messages:
        if message.message_type == "image" and message.media_key:
            message.media_url = storage.generate_private_file_url(
                object_key=message.media_key
            )

    return messages


@router.post("/", response_model=MessageResponse)
async def send_message(
    message: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_chat_member(message.chat_id, current_user.id, db)

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
    )

    db.add(new_message)
    db.commit()
    db.refresh(new_message)

    await manager.broadcast(
        message.chat_id,
        {
            "type": "new_message",
            "message": _build_message_payload(new_message),
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

    return new_message


@router.post("/photo", response_model=MessageResponse)
async def send_photo_message(
    chat_id: int = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _ensure_chat_member(chat_id, current_user.id, db)

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
            "message": _build_message_payload(new_message),
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

    return new_message


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
            "message": _build_message_payload(message),
        },
    )

    return message


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
    media_key = message.media_key if message.message_type == "image" else None

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


@router.get("/{chat_id}", response_model=list[MessageResponse])
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

    return messages