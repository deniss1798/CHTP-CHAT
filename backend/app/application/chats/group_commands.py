from fastapi import HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.application.chats.chat_queries import build_chat_detail_response
from app.application.media.constants import ALLOWED_IMAGE_TYPES, MAX_AVATAR_SIZE
from app.domain.policies.chat_access import require_chat_member
from app.domain.policies.group_chat_policy import require_group_chat
from app.infrastructure.storage.s3_storage import S3StorageService, is_s3_configured
from app.models.chat import Chat
from app.models.user import User
from app.schemas.chat_schema import ChatDetailResponse, ChatUpdate


def rename_group_chat(
    db: Session,
    *,
    chat_id: int,
    current_user: User,
    payload: ChatUpdate,
) -> ChatDetailResponse:
    chat = require_group_chat(
        db.query(Chat).filter(Chat.id == chat_id).first(),
        detail="Only group chats can be renamed",
    )
    require_chat_member(db, chat.id, current_user)

    chat.title = payload.title.strip()
    db.add(chat)
    db.commit()
    db.refresh(chat)

    return build_chat_detail_response(db, chat.id, current_user)


async def upload_group_chat_avatar(
    db: Session,
    *,
    chat_id: int,
    current_user: User,
    file: UploadFile,
) -> ChatDetailResponse:
    chat = require_group_chat(
        db.query(Chat).filter(Chat.id == chat_id).first(),
        detail="Avatar can be changed only for group chats",
    )
    require_chat_member(db, chat.id, current_user)

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

    if len(content) > MAX_AVATAR_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File is too large. Max size is 5 MB",
        )

    if not is_s3_configured():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Public media storage (S3) is not fully configured",
        )

    storage = S3StorageService()
    extension = ALLOWED_IMAGE_TYPES[file.content_type]
    old_avatar_url = chat.avatar_url
    new_avatar_url = storage.upload_public_avatar(
        content=content,
        folder="avatars/chats",
        owner_id=chat.id,
        extension=extension,
        content_type=file.content_type,
    )

    chat.avatar_url = new_avatar_url
    db.add(chat)
    db.commit()
    db.refresh(chat)

    storage.delete_public_object_by_url(old_avatar_url)

    return build_chat_detail_response(db, chat.id, current_user)
