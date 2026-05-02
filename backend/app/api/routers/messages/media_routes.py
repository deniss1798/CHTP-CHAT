from fastapi import APIRouter, Depends, File, Form, UploadFile
from sqlalchemy.orm import Session

from app.application.messages.commands import (
    send_document_message as execute_send_document_message,
    send_photo_message as execute_send_photo_message,
    send_video_message as execute_send_video_message,
    send_video_note_message as execute_send_video_note_message,
    send_voice_message as execute_send_voice_message,
)
from app.core.dependencies import get_current_user
from app.core.rate_limit import MEDIA_UPLOAD_RULE, rate_limiter
from app.db.database import get_db
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
    rate_limiter.check(str(current_user.id), MEDIA_UPLOAD_RULE)
    return await execute_send_photo_message(
        db,
        current_user=current_user,
        chat_id=chat_id,
        file=file,
        reply_to_message_id=reply_to_message_id,
    )


@router.post("/video", response_model=MessageResponse)
async def send_video_message(
    chat_id: int = Form(...),
    file: UploadFile = File(...),
    reply_to_message_id: int | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rate_limiter.check(str(current_user.id), MEDIA_UPLOAD_RULE)
    return await execute_send_video_message(
        db,
        current_user=current_user,
        chat_id=chat_id,
        file=file,
        reply_to_message_id=reply_to_message_id,
    )


@router.post("/video-note", response_model=MessageResponse)
@router.post("/video_note", response_model=MessageResponse)
async def send_video_note_message(
    chat_id: int = Form(...),
    file: UploadFile = File(...),
    reply_to_message_id: int | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rate_limiter.check(str(current_user.id), MEDIA_UPLOAD_RULE)
    return await execute_send_video_note_message(
        db,
        current_user=current_user,
        chat_id=chat_id,
        file=file,
        reply_to_message_id=reply_to_message_id,
    )


@router.post("/voice", response_model=MessageResponse)
async def send_voice_message(
    chat_id: int = Form(...),
    file: UploadFile = File(...),
    reply_to_message_id: int | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rate_limiter.check(str(current_user.id), MEDIA_UPLOAD_RULE)
    return await execute_send_voice_message(
        db,
        current_user=current_user,
        chat_id=chat_id,
        file=file,
        reply_to_message_id=reply_to_message_id,
    )


@router.post("/file", response_model=MessageResponse)
@router.post("/document", response_model=MessageResponse)
async def send_document_message(
    chat_id: int = Form(...),
    file: UploadFile = File(...),
    reply_to_message_id: int | None = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rate_limiter.check(str(current_user.id), MEDIA_UPLOAD_RULE)
    return await execute_send_document_message(
        db,
        current_user=current_user,
        chat_id=chat_id,
        file=file,
        reply_to_message_id=reply_to_message_id,
    )
