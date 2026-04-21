"""Лимиты и MIME для загрузок (слой media по ТЗ)."""

ALLOWED_IMAGE_TYPES: dict[str, str] = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}

MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10 MB

MAX_AVATAR_SIZE = 5 * 1024 * 1024  # 5 MB (чаты / пользователи)

ALLOWED_VIDEO_TYPES: dict[str, str] = {
    "video/mp4": ".mp4",
    "video/webm": ".webm",
    "video/quicktime": ".mov",
    "video/3gpp": ".3gp",
    "video/3gp": ".3gp",
}

MAX_VIDEO_SIZE = 50 * 1024 * 1024  # 50 MB

MAX_DOCUMENT_SIZE = 50 * 1024 * 1024  # 50 MB

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

MAX_VOICE_SIZE = 10 * 1024 * 1024  # 10 MB

ALLOWED_VOICE_TYPES: dict[str, str] = {
    "audio/ogg": ".ogg",
    "audio/opus": ".opus",
    "audio/mpeg": ".mp3",
    "audio/mp4": ".m4a",
    "audio/aac": ".aac",
    "audio/webm": ".webm",
    "audio/x-m4a": ".m4a",
    "audio/wav": ".wav",
}

PRIVATE_MEDIA_MESSAGE_TYPES: frozenset[str] = frozenset(
    {"image", "video", "video_note", "document", "voice"}
)
