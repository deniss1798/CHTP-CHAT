from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict
s3_endpoint_url: str | None = Field(None, alias="S3_ENDPOINT_URL")
s3_region: str | None = Field(None, alias="S3_REGION")
s3_access_key_id: str | None = Field(None, alias="S3_ACCESS_KEY_ID")
s3_secret_access_key: str | None = Field(None, alias="S3_SECRET_ACCESS_KEY")
s3_public_bucket: str | None = Field(None, alias="S3_PUBLIC_BUCKET")
s3_private_bucket: str | None = Field(None, alias="S3_PRIVATE_BUCKET")
s3_public_base_url: str | None = Field(None, alias="S3_PUBLIC_BASE_URL")


class Settings(BaseSettings):
    app_name: str = "ЧТП ЧАТ API"
    debug: bool = False

    database_url: str = Field(..., alias="DATABASE_URL")

    secret_key: str = Field(..., alias="SECRET_KEY")
    algorithm: str = Field("HS256", alias="ALGORITHM")
    access_token_expire_minutes: int = Field(10080, alias="ACCESS_TOKEN_EXPIRE_MINUTES")

    smtp_host: str = Field(..., alias="SMTP_HOST")
    smtp_port: int = Field(..., alias="SMTP_PORT")
    smtp_user: str = Field(..., alias="SMTP_USER")
    smtp_password: str = Field(..., alias="SMTP_PASSWORD")
    smtp_from: str = Field(..., alias="SMTP_FROM")

    firebase_service_account_file: str | None = Field(
        None,
        alias="FIREBASE_SERVICE_ACCOUNT_FILE",
    )
    firebase_service_account_json: str | None = Field(
        None,
        alias="FIREBASE_SERVICE_ACCOUNT_JSON",
    )

    cors_origins: str = Field("", alias="CORS_ORIGINS")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()