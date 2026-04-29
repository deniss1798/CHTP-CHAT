from functools import lru_cache

from pydantic import AliasChoices, Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


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

    # Поддержка и S3_*, и стандартных AWS_* (часто так задают в .env / панели хостинга).
    s3_endpoint_url: str | None = Field(
        None,
        validation_alias=AliasChoices("S3_ENDPOINT_URL", "AWS_ENDPOINT_URL"),
    )
    s3_region: str | None = Field(
        None,
        validation_alias=AliasChoices("S3_REGION", "AWS_DEFAULT_REGION"),
    )
    s3_access_key_id: str | None = Field(
        None,
        validation_alias=AliasChoices("S3_ACCESS_KEY_ID", "AWS_ACCESS_KEY_ID"),
    )
    s3_secret_access_key: str | None = Field(
        None,
        validation_alias=AliasChoices("S3_SECRET_ACCESS_KEY", "AWS_SECRET_ACCESS_KEY"),
    )
    s3_public_bucket: str | None = Field(None, validation_alias="S3_PUBLIC_BUCKET")
    s3_private_bucket: str | None = Field(None, validation_alias="S3_PRIVATE_BUCKET")
    s3_public_base_url: str | None = Field(None, validation_alias="S3_PUBLIC_BASE_URL")
    s3_connect_timeout_seconds: float = Field(3.0, alias="S3_CONNECT_TIMEOUT_SECONDS")
    s3_read_timeout_seconds: float = Field(15.0, alias="S3_READ_TIMEOUT_SECONDS")
    private_media_url_ttl_seconds: int = Field(
        900,
        ge=60,
        le=86400,
        alias="PRIVATE_MEDIA_URL_TTL_SECONDS",
    )
    story_media_url_ttl_seconds: int = Field(
        7200,
        ge=60,
        le=86400,
        alias="STORY_MEDIA_URL_TTL_SECONDS",
    )

    redis_url: str | None = Field(None, alias="REDIS_URL")
    redis_socket_timeout_seconds: float = Field(2.0, alias="REDIS_SOCKET_TIMEOUT_SECONDS")
    redis_socket_connect_timeout_seconds: float = Field(
        2.0,
        alias="REDIS_SOCKET_CONNECT_TIMEOUT_SECONDS",
    )

    smtp_timeout_seconds: float = Field(20.0, alias="SMTP_TIMEOUT_SECONDS")
    push_send_timeout_seconds: float = Field(8.0, alias="PUSH_SEND_TIMEOUT_SECONDS")

    @field_validator(
        "s3_endpoint_url",
        "s3_region",
        "s3_access_key_id",
        "s3_secret_access_key",
        "s3_public_bucket",
        "s3_private_bucket",
        "s3_public_base_url",
        "redis_url",
        mode="before",
    )
    @classmethod
    def _strip_s3_env(cls, v: object) -> str | None:
        if v is None:
            return None
        s = str(v).strip()
        return s if s else None

    cors_origins: str = Field("", alias="CORS_ORIGINS")

    # --- WebRTC / TURN (coturn REST + static-auth-secret) ---
    # Если заданы secret и host — API выдаёт временные username/credential для TURN.
    turn_static_auth_secret: str | None = Field(
        None,
        alias="TURN_STATIC_AUTH_SECRET",
    )
    turn_server_host: str | None = Field(
        None,
        alias="TURN_SERVER_HOST",
        description="Публичный hostname или IP coturn для клиентов",
    )
    turn_udp_port: int = Field(3478, alias="TURN_UDP_PORT")
    turn_tls_port: int | None = Field(None, alias="TURN_TLS_PORT")
    turn_credential_ttl_seconds: int = Field(
        3600,
        ge=300,
        le=86400,
        alias="TURN_CREDENTIAL_TTL_SECONDS",
    )
    webrtc_fallback_stun_urls: str = Field(
        "stun:stun.l.google.com:19302,stun:stun1.l.google.com:19302",
        alias="WEBRTC_FALLBACK_STUN_URLS",
    )

    # Log JSON with method/path/duration and set X-Response-Time-Ms (load tests / ops).
    perf_log_requests: bool = Field(False, alias="PERF_LOG_REQUESTS")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
