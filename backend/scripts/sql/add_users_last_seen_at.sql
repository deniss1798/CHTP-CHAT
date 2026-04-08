-- Колонка для «в сети» (соответствует миграции b2c3d4e5f6a7_add_users_last_seen_at).
-- PostgreSQL. Выполни в psql / DBeaver / pgAdmin, если не используешь Alembic.

ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ NULL;
