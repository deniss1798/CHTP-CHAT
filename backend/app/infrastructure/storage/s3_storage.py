import mimetypes
from uuid import uuid4

import boto3
from botocore.client import Config

from app.core.config import get_settings


def _env_nonempty(value: str | None) -> bool:
    return bool(value and str(value).strip())


def is_private_s3_ready() -> bool:
    """Достаточно для presigned URL и загрузки в приватный бакет (чаты, медиа)."""
    s = get_settings()
    return bool(
        _env_nonempty(s.s3_endpoint_url)
        and _env_nonempty(s.s3_access_key_id)
        and _env_nonempty(s.s3_secret_access_key)
        and _env_nonempty(s.s3_private_bucket)
    )


def is_s3_configured() -> bool:
    """Полный набор: приватный + публичный бакет (аватары, публичные URL)."""
    s = get_settings()
    return is_private_s3_ready() and bool(
        _env_nonempty(s.s3_public_bucket) and _env_nonempty(s.s3_public_base_url)
    )


class S3StorageService:
    def __init__(self) -> None:
        settings = get_settings()

        if not settings.s3_endpoint_url:
            raise RuntimeError("S3_ENDPOINT_URL is not set")
        if not settings.s3_access_key_id:
            raise RuntimeError("S3_ACCESS_KEY_ID is not set")
        if not settings.s3_secret_access_key:
            raise RuntimeError("S3_SECRET_ACCESS_KEY is not set")
        if not settings.s3_private_bucket:
            raise RuntimeError("S3_PRIVATE_BUCKET is not set")

        region = (settings.s3_region or "").strip() or "us-east-1"

        self.settings = settings
        self.client = boto3.client(
            "s3",
            endpoint_url=settings.s3_endpoint_url,
            region_name=region,
            aws_access_key_id=settings.s3_access_key_id,
            aws_secret_access_key=settings.s3_secret_access_key,
            config=Config(
                signature_version="s3v4",
                connect_timeout=settings.s3_connect_timeout_seconds,
                read_timeout=settings.s3_read_timeout_seconds,
                retries={"max_attempts": 3, "mode": "standard"},
            ),
        )

    def _build_public_url(self, object_key: str) -> str:
        base = self.settings.s3_public_base_url
        if not base:
            raise RuntimeError("S3_PUBLIC_BASE_URL is not set")
        base = base.rstrip("/")
        return f"{base}/{object_key}"

    def upload_public_avatar(
        self,
        *,
        content: bytes,
        folder: str,
        owner_id: int,
        extension: str,
        content_type: str | None = None,
    ) -> str:
        if not self.settings.s3_public_bucket:
            raise RuntimeError("S3_PUBLIC_BUCKET is not set")
        object_key = f"{folder}/{owner_id}/{uuid4().hex}{extension}"

        resolved_content_type = (
            content_type
            or mimetypes.guess_type(object_key)[0]
            or "application/octet-stream"
        )

        self.client.put_object(
            Bucket=self.settings.s3_public_bucket,
            Key=object_key,
            Body=content,
            ContentType=resolved_content_type,
        )

        return self._build_public_url(object_key)

    def delete_public_object_by_url(self, file_url: str | None) -> None:
        if not file_url:
            return

        pub_base = self.settings.s3_public_base_url
        if not self.settings.s3_public_bucket or not pub_base:
            return

        base = pub_base.rstrip("/") + "/"
        if not file_url.startswith(base):
            return

        object_key = file_url.removeprefix(base)
        if not object_key:
            return

        self.client.delete_object(
            Bucket=self.settings.s3_public_bucket,
            Key=object_key,
        )

    def upload_private_message_image(
        self,
        *,
        content: bytes,
        chat_id: int,
        extension: str,
        content_type: str | None = None,
    ) -> tuple[str, str]:
        object_key = f"messages/images/{chat_id}/{uuid4().hex}{extension}"

        resolved_content_type = (
            content_type
            or mimetypes.guess_type(object_key)[0]
            or "application/octet-stream"
        )

        self.client.put_object(
            Bucket=self.settings.s3_private_bucket,
            Key=object_key,
            Body=content,
            ContentType=resolved_content_type,
        )

        return object_key, f"s3://{self.settings.s3_private_bucket}/{object_key}"

    def upload_private_message_video(
        self,
        *,
        content: bytes,
        chat_id: int,
        extension: str,
        content_type: str | None = None,
    ) -> tuple[str, str]:
        object_key = f"messages/videos/{chat_id}/{uuid4().hex}{extension}"

        resolved_content_type = (
            content_type
            or mimetypes.guess_type(object_key)[0]
            or "application/octet-stream"
        )

        self.client.put_object(
            Bucket=self.settings.s3_private_bucket,
            Key=object_key,
            Body=content,
            ContentType=resolved_content_type,
        )

        return object_key, f"s3://{self.settings.s3_private_bucket}/{object_key}"

    def upload_private_message_video_note(
        self,
        *,
        content: bytes,
        chat_id: int,
        extension: str,
        content_type: str | None = None,
    ) -> tuple[str, str]:
        object_key = f"messages/video_notes/{chat_id}/{uuid4().hex}{extension}"

        resolved_content_type = (
            content_type
            or mimetypes.guess_type(object_key)[0]
            or "application/octet-stream"
        )

        self.client.put_object(
            Bucket=self.settings.s3_private_bucket,
            Key=object_key,
            Body=content,
            ContentType=resolved_content_type,
        )

        return object_key, f"s3://{self.settings.s3_private_bucket}/{object_key}"

    def upload_private_message_document(
        self,
        *,
        content: bytes,
        chat_id: int,
        extension: str,
        content_type: str | None = None,
    ) -> tuple[str, str]:
        object_key = f"messages/documents/{chat_id}/{uuid4().hex}{extension}"

        resolved_content_type = (
            content_type
            or mimetypes.guess_type(object_key)[0]
            or "application/octet-stream"
        )

        self.client.put_object(
            Bucket=self.settings.s3_private_bucket,
            Key=object_key,
            Body=content,
            ContentType=resolved_content_type,
        )

        return object_key, f"s3://{self.settings.s3_private_bucket}/{object_key}"

    def upload_private_message_voice(
        self,
        *,
        content: bytes,
        chat_id: int,
        extension: str,
        content_type: str | None = None,
    ) -> tuple[str, str]:
        object_key = f"messages/voice/{chat_id}/{uuid4().hex}{extension}"

        resolved_content_type = (
            content_type
            or mimetypes.guess_type(object_key)[0]
            or "application/octet-stream"
        )

        self.client.put_object(
            Bucket=self.settings.s3_private_bucket,
            Key=object_key,
            Body=content,
            ContentType=resolved_content_type,
        )

        return object_key, f"s3://{self.settings.s3_private_bucket}/{object_key}"

    def upload_private_story_image(
        self,
        *,
        user_id: int,
        content: bytes,
        extension: str,
        content_type: str | None = None,
    ) -> tuple[str, str]:
        object_key = f"stories/images/{user_id}/{uuid4().hex}{extension}"

        resolved_content_type = (
            content_type
            or mimetypes.guess_type(object_key)[0]
            or "application/octet-stream"
        )

        self.client.put_object(
            Bucket=self.settings.s3_private_bucket,
            Key=object_key,
            Body=content,
            ContentType=resolved_content_type,
        )

        return object_key, f"s3://{self.settings.s3_private_bucket}/{object_key}"

    def upload_private_story_video(
        self,
        *,
        user_id: int,
        content: bytes,
        extension: str,
        content_type: str | None = None,
    ) -> tuple[str, str]:
        object_key = f"stories/videos/{user_id}/{uuid4().hex}{extension}"

        resolved_content_type = (
            content_type
            or mimetypes.guess_type(object_key)[0]
            or "application/octet-stream"
        )

        self.client.put_object(
            Bucket=self.settings.s3_private_bucket,
            Key=object_key,
            Body=content,
            ContentType=resolved_content_type,
        )

        return object_key, f"s3://{self.settings.s3_private_bucket}/{object_key}"

    def generate_private_file_url(
        self,
        *,
        object_key: str,
        expires_in: int = 900,
    ) -> str:
        return self.client.generate_presigned_url(
            "get_object",
            Params={
                "Bucket": self.settings.s3_private_bucket,
                "Key": object_key,
            },
            ExpiresIn=expires_in,
        )

    def delete_private_object(self, object_key: str | None) -> None:
        if not object_key:
            return

        self.client.delete_object(
            Bucket=self.settings.s3_private_bucket,
            Key=object_key,
        )
