import os
import re

from fastapi import HTTPException, UploadFile, status

from app.application.media.constants import ALLOWED_DOCUMENT_EXTENSIONS
from app.application.messages.message_projection import safe_message_text, safe_message_type
from app.models.message import Message


def push_preview_for_message(message: Message) -> str:
    t = safe_message_text(message).strip()
    if t:
        return t
    mt = safe_message_type(message)
    if mt == "image":
        return "📷 Фото"
    if mt == "video":
        return "🎥 Видео"
    if mt == "video_note":
        return "🎥 Видеосообщение"
    if mt in {"document", "file"}:
        return "📎 Файл"
    if mt == "voice":
        return "🎤 Голосовое"
    return "Новое сообщение"


def sanitize_document_filename(name: str | None) -> str:
    if not name:
        return "file"
    base = os.path.basename(str(name).replace("\\", "/"))
    base = base.strip() or "file"
    base = re.sub(r"[\x00-\x1f\x7f]", "", base)
    base = re.sub(r"[^a-zA-Z0-9._\-() \u0400-\u04FF]", "_", base)
    if len(base) > 200:
        root, ext = os.path.splitext(base)
        base = root[:180] + ext
    return base or "file"


def validate_document_file(
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
