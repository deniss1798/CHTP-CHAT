-- Ручные миграции (эквивалент Alembic), PostgreSQL.
-- Запуск: psql -U postgres -d postgres -f postgres_manual_migrations.sql
-- Или через pgAdmin / DBeaver. Скрипт идемпотентен: повторный запуск безопасен.

-- =============================================================================
-- 7f2a9c1d4e50 — reply_to_message_id в messages
-- =============================================================================
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS reply_to_message_id BIGINT;

CREATE INDEX IF NOT EXISTS ix_messages_reply_to_message_id
  ON messages (reply_to_message_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_messages_reply_to_message_id'
  ) THEN
    ALTER TABLE messages
      ADD CONSTRAINT fk_messages_reply_to_message_id
      FOREIGN KEY (reply_to_message_id)
      REFERENCES messages (id)
      ON DELETE SET NULL;
  END IF;
END $$;

-- =============================================================================
-- a1b2c3d4e5f6 — last_read_message_id в chat_members
-- =============================================================================
ALTER TABLE chat_members
  ADD COLUMN IF NOT EXISTS last_read_message_id BIGINT;

CREATE INDEX IF NOT EXISTS ix_chat_members_last_read_message_id
  ON chat_members (last_read_message_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_chat_members_last_read_message_id'
  ) THEN
    ALTER TABLE chat_members
      ADD CONSTRAINT fk_chat_members_last_read_message_id
      FOREIGN KEY (last_read_message_id)
      REFERENCES messages (id)
      ON DELETE SET NULL;
  END IF;
END $$;

-- =============================================================================
-- b2c3d4e5f6a7 — last_seen_at в users (TIMESTAMPTZ)
-- =============================================================================
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;

-- =============================================================================
-- c9d0e1f2a3b4 — forwarded_from_user_id в messages (пересылки)
-- =============================================================================
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS forwarded_from_user_id BIGINT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_messages_forwarded_from_user_id'
  ) THEN
    ALTER TABLE messages
      ADD CONSTRAINT fk_messages_forwarded_from_user_id
      FOREIGN KEY (forwarded_from_user_id)
      REFERENCES users (id)
      ON DELETE SET NULL;
  END IF;
END $$;
