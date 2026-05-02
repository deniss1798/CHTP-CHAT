import asyncio
from io import BytesIO

import pytest
from fastapi import HTTPException, UploadFile
from starlette.datastructures import Headers

from app.application.media.constants import (
    MAX_DOCUMENT_SIZE,
    MAX_IMAGE_SIZE,
    MAX_VIDEO_SIZE,
    MAX_VOICE_SIZE,
    PRIVATE_MEDIA_MESSAGE_TYPES,
)
from app.application.messages.document_rules import (
    sanitize_document_filename,
    validate_document_file,
)
from app.services.media_service import read_and_validate_photo


def _upload_file(
    *,
    filename: str,
    content_type: str,
    content: bytes = b"payload",
) -> UploadFile:
    return UploadFile(
        file=BytesIO(content),
        filename=filename,
        headers=Headers({"content-type": content_type}),
    )


def test_media_limits_match_current_contract() -> None:
    assert MAX_IMAGE_SIZE == 15 * 1024 * 1024
    assert MAX_VIDEO_SIZE == 100 * 1024 * 1024
    assert MAX_DOCUMENT_SIZE == 100 * 1024 * 1024
    assert MAX_VOICE_SIZE == 20 * 1024 * 1024


def test_private_media_types_include_file_alias() -> None:
    assert "document" in PRIVATE_MEDIA_MESSAGE_TYPES
    assert "file" in PRIVATE_MEDIA_MESSAGE_TYPES


def test_sanitize_document_filename_strips_paths_and_control_chars() -> None:
    safe = sanitize_document_filename("../bad/\x00report?.pdf")

    assert safe == "report_.pdf"


def test_validate_document_file_rejects_mime_extension_mismatch() -> None:
    upload = _upload_file(filename="report.pdf", content_type="text/plain")

    with pytest.raises(HTTPException) as exc_info:
        validate_document_file(upload, "report.pdf")

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail == "Content-type does not match file extension"


def test_validate_document_file_rejects_double_extension_executable() -> None:
    upload = _upload_file(
        filename="photo.jpg.exe",
        content_type="application/octet-stream",
    )

    with pytest.raises(HTTPException) as exc_info:
        validate_document_file(upload, "photo.jpg.exe")

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail == "File type not allowed"


def test_validate_document_file_accepts_octet_stream_with_extension() -> None:
    upload = _upload_file(
        filename="report.pdf",
        content_type="application/octet-stream",
    )

    ext, mime = validate_document_file(upload, "report.pdf")

    assert ext == ".pdf"
    assert mime == "application/pdf"


def test_photo_validation_rejects_spoofed_content_type() -> None:
    upload = _upload_file(
        filename="fake.png",
        content_type="image/png",
        content=b"not a png",
    )

    with pytest.raises(HTTPException) as exc_info:
        asyncio.run(read_and_validate_photo(upload))

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail == "Image content does not match declared type"


def test_photo_validation_accepts_png_signature() -> None:
    upload = _upload_file(
        filename="ok.png",
        content_type="image/png",
        content=b"\x89PNG\r\n\x1a\n" + b"data",
    )

    content, content_type = asyncio.run(read_and_validate_photo(upload))

    assert content.startswith(b"\x89PNG")
    assert content_type == "image/png"
