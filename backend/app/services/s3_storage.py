import mimetypes
from uuid import uuid4

import boto3
from botocore.client import Config

from app.core.config import get_settings


class S3StorageService:
    def __init__(self) -> None:
        settings = get_settings()

        if not settings.s3_endpoint_url:
            raise RuntimeError("S3_ENDPOINT_URL is not set")
        if not settings.s3_region:
            raise RuntimeError("S3_REGION is not set")
        if not settings.s3_access_key_id:
            raise RuntimeError("S3_ACCESS_KEY_ID is not set")
        if not settings.s3_secret_access_key:
            raise RuntimeError("S3_SECRET_ACCESS_KEY is not set")
        if not settings.s3_public_bucket:
            raise RuntimeError("S3_PUBLIC_BUCKET is not set")
        if not settings.s3_private_bucket:
            raise RuntimeError("S3_PRIVATE_BUCKET is not set")
        if not settings.s3_public_base_url:
            raise RuntimeError("S3_PUBLIC_BASE_URL is not set")

        self.settings = settings
        self.client = boto3.client(
            "s3",
            endpoint_url=settings.s3_endpoint_url,
            region_name=settings.s3_region,
            aws_access_key_id=settings.s3_access_key_id,
            aws_secret_access_key=settings.s3_secret_access_key,
            config=Config(signature_version="s3v4"),
        )

    def _build_public_url(self, object_key: str) -> str:
        base = self.settings.s3_public_base_url.rstrip("/")
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

        base = self.settings.s3_public_base_url.rstrip("/") + "/"
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

    def generate_private_file_url(
        self,
        *,
        object_key: str,
        expires_in: int = 3600,
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