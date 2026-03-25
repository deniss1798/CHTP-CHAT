from functools import lru_cache

from pydantic import Field
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

   # firebase_credentials_path: str = Field(..., alias="FIREBASE_CREDENTIALS_PATH")
    firebase_credentials_path: str | None = Field(None, alias="FIREBASE_CREDENTIALS_PATH")
    firebase_service_account_json: str | None = Field(None, alias="FIREBASE_SERVICE_ACCOUNT_JSON")
    

    cors_origins: str = Field("", alias="CORS_ORIGINS")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()