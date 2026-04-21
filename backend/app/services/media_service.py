"""Загрузка медиа сообщений (S3) и проверки размера/MIME."""

from fastapi import HTTPException, UploadFile, status

from app.application.media.constants import (
    ALLOWED_IMAGE_TYPES,
    ALLOWED_VIDEO_TYPES,
    ALLOWED_VOICE_TYPES,
    MAX_DOCUMENT_SIZE,
    MAX_IMAGE_SIZE,
    MAX_VIDEO_SIZE,
    MAX_VOICE_SIZE,
)
from app.application.messages.document_rules import (
    sanitize_document_filename,
    validate_document_file,
)
from app.infrastructure.media.video_transcode import try_transcode_to_desktop_mp4
from app.infrastructure.storage.s3_storage import S3StorageService, is_private_s3_ready


def require_private_s3_or_503() -> None:
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


def delete_private_media_key(media_key: str | None) -> None:
    if not media_key or not is_private_s3_ready():
        return
    try:
        S3StorageService().delete_private_object(media_key)
    except Exception as e:
        print(f"Private media delete skipped: {e}")


async def read_and_validate_photo(file: UploadFile) -> tuple[bytes, str]:
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
    return content, file.content_type


def upload_private_message_image(
    *,
    chat_id: int,
    content: bytes,
    content_type: str,
) -> tuple[str, str]:
    storage = S3StorageService()
    extension = ALLOWED_IMAGE_TYPES[content_type]
    return storage.upload_private_message_image(
        content=content,
        chat_id=chat_id,
        extension=extension,
        content_type=content_type,
    )


async def read_and_prepare_video(file: UploadFile) -> tuple[bytes, str, str]:
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

    assert extension is not None
    return content, extension, media_content_type


def upload_private_message_video(
    *,
    chat_id: int,
    content: bytes,
    extension: str,
    content_type: str,
) -> tuple[str, str]:
    storage = S3StorageService()
    return storage.upload_private_message_video(
        content=content,
        chat_id=chat_id,
        extension=extension,
        content_type=content_type,
    )


def upload_private_message_video_note(
    *,
    chat_id: int,
    content: bytes,
    extension: str,
    content_type: str,
) -> tuple[str, str]:
    storage = S3StorageService()
    return storage.upload_private_message_video_note(
        content=content,
        chat_id=chat_id,
        extension=extension,
        content_type=content_type,
    )


async def read_and_validate_document(
    file: UploadFile,
) -> tuple[bytes, str, str, str]:
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
    return content, safe_name, ext, resolved_mime


def upload_private_message_document(
    *,
    chat_id: int,
    content: bytes,
    extension: str,
    content_type: str,
) -> tuple[str, str]:
    storage = S3StorageService()
    return storage.upload_private_message_document(
        content=content,
        chat_id=chat_id,
        extension=extension,
        content_type=content_type,
    )


async def read_and_validate_voice(file: UploadFile) -> tuple[bytes, str, str]:
    ct_raw = (file.content_type or "").split(";")[0].strip().lower()
    extension: str | None = None
    if ct_raw in ALLOWED_VOICE_TYPES:
        extension = ALLOWED_VOICE_TYPES[ct_raw]
    else:
        lower_name = (file.filename or "").lower()
        for ext, ert in (
            (".m4a", "audio/mp4"),
            (".ogg", "audio/ogg"),
            (".opus", "audio/opus"),
            (".mp3", "audio/mpeg"),
            (".aac", "audio/aac"),
            (".webm", "audio/webm"),
            (".wav", "audio/wav"),
        ):
            if lower_name.endswith(ext):
                ct_raw = ert
                extension = ALLOWED_VOICE_TYPES[ert]
                break
    if extension is None or ct_raw not in ALLOWED_VOICE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported audio format",
        )
    content = await file.read()
    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty file",
        )
    if len(content) > MAX_VOICE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File is too large. Max size is 10 MB",
        )
    return content, extension, ct_raw


def upload_private_message_voice(
    *,
    chat_id: int,
    content: bytes,
    extension: str,
    content_type: str,
) -> tuple[str, str]:
    storage = S3StorageService()
    return storage.upload_private_message_voice(
        content=content,
        chat_id=chat_id,
        extension=extension,
        content_type=content_type,
    )


def presign_media_url(media_key: str | None) -> str | None:
    if not media_key:
        return None
    return S3StorageService().generate_private_file_url(object_key=media_key)
