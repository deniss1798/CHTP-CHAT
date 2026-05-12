-- Ручное приведение схемы PostgreSQL к состоянию «как после всех Alembic до k3l4m5n6o7p8».
-- Запускай в DBeaver по очереди блоками или целиком (одна транзакция: BEGIN; … COMMIT;).
-- Перед запуском: бэкап БД. Если какой-то блок падает из-за данных (дубликаты) — правь данные и повтори.

-- =============================================================================
-- 3b8cdbea68d6 — правки chat_members / messages / индексы (идемпотентно)
-- =============================================================================
ALTER TABLE chat_members
  ALTER COLUMN role DROP DEFAULT;
ALTER TABLE chat_members
  ALTER COLUMN role SET NOT NULL;

ALTER TABLE chat_members DROP CONSTRAINT IF EXISTS chat_members_chat_id_user_id_key;
DROP INDEX IF EXISTS idx_chat_members_chat_id;
DROP INDEX IF EXISTS idx_chat_members_user_id;

CREATE INDEX IF NOT EXISTS ix_chat_members_id ON chat_members (id);

ALTER TABLE chat_members DROP CONSTRAINT IF EXISTS uq_chat_members_chat_user;
DROP INDEX IF EXISTS uq_chat_members_chat_user;

DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname = 'chat_members' AND c.conname = 'uq_chat_members_chat_user'
  ) THEN
    ALTER TABLE chat_members
      ADD CONSTRAINT uq_chat_members_chat_user UNIQUE (chat_id, user_id);
  END IF;
END
$body$ LANGUAGE plpgsql;

CREATE INDEX IF NOT EXISTS ix_chats_id ON chats (id);

ALTER TABLE messages ALTER COLUMN is_updated DROP DEFAULT;

DROP INDEX IF EXISTS idx_messages_chat_id;
CREATE INDEX IF NOT EXISTS ix_messages_id ON messages (id);
CREATE INDEX IF NOT EXISTS ix_users_id ON users (id);

-- =============================================================================
-- 7f2a9c1d4e50 — reply_to_message_id
-- =============================================================================
DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'messages' AND column_name = 'reply_to_message_id'
  ) THEN
    ALTER TABLE messages ADD COLUMN reply_to_message_id BIGINT;
  END IF;
END
$body$ LANGUAGE plpgsql;

CREATE INDEX IF NOT EXISTS ix_messages_reply_to_message_id ON messages (reply_to_message_id);

DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname = 'messages' AND c.conname = 'fk_messages_reply_to_message_id'
  ) THEN
    ALTER TABLE messages
      ADD CONSTRAINT fk_messages_reply_to_message_id
      FOREIGN KEY (reply_to_message_id) REFERENCES messages (id) ON DELETE SET NULL;
  END IF;
END
$body$ LANGUAGE plpgsql;

-- =============================================================================
-- a1b2c3d4e5f6 — last_read_message_id в chat_members
-- =============================================================================
DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'chat_members' AND column_name = 'last_read_message_id'
  ) THEN
    ALTER TABLE chat_members ADD COLUMN last_read_message_id BIGINT;
  END IF;
END
$body$ LANGUAGE plpgsql;

CREATE INDEX IF NOT EXISTS ix_chat_members_last_read_message_id ON chat_members (last_read_message_id);

DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname = 'chat_members' AND c.conname = 'fk_chat_members_last_read_message_id'
  ) THEN
    ALTER TABLE chat_members
      ADD CONSTRAINT fk_chat_members_last_read_message_id
      FOREIGN KEY (last_read_message_id) REFERENCES messages (id) ON DELETE SET NULL;
  END IF;
END
$body$ LANGUAGE plpgsql;

-- =============================================================================
-- b2c3d4e5f6a7 — users.last_seen_at
-- =============================================================================
DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'last_seen_at'
  ) THEN
    ALTER TABLE users ADD COLUMN last_seen_at TIMESTAMPTZ NULL;
  END IF;
END
$body$ LANGUAGE plpgsql;

-- =============================================================================
-- c9d0e1f2a3b4 — forwarded_from_user_id
-- =============================================================================
DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'messages' AND column_name = 'forwarded_from_user_id'
  ) THEN
    ALTER TABLE messages ADD COLUMN forwarded_from_user_id BIGINT;
  END IF;
END
$body$ LANGUAGE plpgsql;

DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname = 'messages' AND c.conname = 'fk_messages_forwarded_from_user_id'
  ) THEN
    ALTER TABLE messages
      ADD CONSTRAINT fk_messages_forwarded_from_user_id
      FOREIGN KEY (forwarded_from_user_id) REFERENCES users (id) ON DELETE SET NULL;
  END IF;
END
$body$ LANGUAGE plpgsql;

-- =============================================================================
-- d1e2f3a4b5c6 — индекс списка сообщений
-- =============================================================================
CREATE INDEX IF NOT EXISTS ix_messages_chat_id_created_at ON messages (chat_id, created_at);

-- =============================================================================
-- e2f3a4b5c6d7 — message_reactions
-- =============================================================================
CREATE TABLE IF NOT EXISTS message_reactions (
  id BIGSERIAL PRIMARY KEY,
  message_id BIGINT NOT NULL REFERENCES messages (id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  emoji VARCHAR(32) NOT NULL,
  created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
  CONSTRAINT uq_message_reaction_user_emoji UNIQUE (message_id, user_id, emoji)
);
CREATE INDEX IF NOT EXISTS ix_message_reactions_message_id ON message_reactions (message_id);

-- =============================================================================
-- f3a4b5c6d7e8 — длина verification_code (если таблица есть)
-- =============================================================================
DO $body$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'pending_registrations'
  ) THEN
    ALTER TABLE pending_registrations
      ALTER COLUMN verification_code TYPE VARCHAR(255);
  END IF;
END
$body$ LANGUAGE plpgsql;

-- =============================================================================
-- a4b5c6d7e8f9 — messages.is_deleted
-- =============================================================================
DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'messages' AND column_name = 'is_deleted'
  ) THEN
    ALTER TABLE messages ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT false;
    ALTER TABLE messages ALTER COLUMN is_deleted DROP DEFAULT;
  END IF;
END
$body$ LANGUAGE plpgsql;

-- =============================================================================
-- b5c6d7e8f9a0 — notification_settings
-- =============================================================================
CREATE TABLE IF NOT EXISTS notification_settings (
  user_id BIGINT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  notifications_enabled BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =============================================================================
-- f6a7b8c9d0e1 — индексы производительности
-- =============================================================================
CREATE INDEX IF NOT EXISTS ix_messages_chat_id_id ON messages (chat_id, id);
CREATE INDEX IF NOT EXISTS ix_messages_chat_id_created_at_id ON messages (chat_id, created_at, id);
CREATE INDEX IF NOT EXISTS ix_chat_members_user_chat ON chat_members (user_id, chat_id);

-- =============================================================================
-- g7h8i9j0k1l2 — stories + story_views
-- =============================================================================
CREATE TABLE IF NOT EXISTS stories (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  media_key TEXT NOT NULL,
  media_type VARCHAR(20) NOT NULL,
  caption TEXT NULL,
  created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
  expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_stories_id ON stories (id);
CREATE INDEX IF NOT EXISTS ix_stories_user_id ON stories (user_id);
CREATE INDEX IF NOT EXISTS ix_stories_expires_at ON stories (expires_at);
CREATE INDEX IF NOT EXISTS ix_stories_user_expires ON stories (user_id, expires_at);

CREATE TABLE IF NOT EXISTS story_views (
  id BIGSERIAL PRIMARY KEY,
  story_id BIGINT NOT NULL REFERENCES stories (id) ON DELETE CASCADE,
  viewer_user_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  viewed_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
  CONSTRAINT uq_story_views_story_viewer UNIQUE (story_id, viewer_user_id)
);
CREATE INDEX IF NOT EXISTS ix_story_views_story_id ON story_views (story_id);
CREATE INDEX IF NOT EXISTS ix_story_views_viewer_user_id ON story_views (viewer_user_id);
CREATE INDEX IF NOT EXISTS ix_story_views_viewer ON story_views (viewer_user_id);

-- =============================================================================
-- a7b8c9d0e1f2 — calls
-- =============================================================================
CREATE TABLE IF NOT EXISTS calls (
  id BIGINT PRIMARY KEY,
  chat_id BIGINT NOT NULL REFERENCES chats (id) ON DELETE CASCADE,
  initiator_id BIGINT REFERENCES users (id) ON DELETE SET NULL,
  type VARCHAR(32) NOT NULL DEFAULT 'voice',
  status VARCHAR(32) NOT NULL DEFAULT 'created',
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  accepted_at TIMESTAMPTZ NULL,
  ended_at TIMESTAMPTZ NULL,
  duration_seconds INTEGER NULL,
  client_call_id TEXT NULL
);
CREATE INDEX IF NOT EXISTS ix_calls_id ON calls (id);
CREATE INDEX IF NOT EXISTS ix_calls_chat_id ON calls (chat_id);
CREATE INDEX IF NOT EXISTS ix_calls_initiator_id ON calls (initiator_id);
CREATE INDEX IF NOT EXISTS ix_calls_status ON calls (status);

DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname = 'calls' AND c.conname = 'uq_calls_client_call_id'
  ) THEN
    ALTER TABLE calls
      ADD CONSTRAINT uq_calls_client_call_id UNIQUE (client_call_id);
  END IF;
END
$body$ LANGUAGE plpgsql;

-- =============================================================================
-- c8d9e0f1a2b3 — индексы device_tokens / calls (таблица device_tokens должна уже быть)
-- =============================================================================
DO $body$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'device_tokens'
  ) THEN
    CREATE INDEX IF NOT EXISTS ix_device_tokens_user_updated_id
      ON device_tokens (user_id, updated_at, id);
  END IF;
END
$body$ LANGUAGE plpgsql;
CREATE INDEX IF NOT EXISTS ix_calls_started_at_id ON calls (started_at, id);
CREATE INDEX IF NOT EXISTS ix_calls_chat_started_id ON calls (chat_id, started_at, id);

-- =============================================================================
-- h1i2j3k4l5m6 — архив / mute в chat_members
-- =============================================================================
DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'chat_members' AND column_name = 'is_archived'
  ) THEN
    ALTER TABLE chat_members ADD COLUMN is_archived BOOLEAN NOT NULL DEFAULT false;
    ALTER TABLE chat_members ALTER COLUMN is_archived DROP DEFAULT;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'chat_members' AND column_name = 'notifications_muted'
  ) THEN
    ALTER TABLE chat_members ADD COLUMN notifications_muted BOOLEAN NOT NULL DEFAULT false;
    ALTER TABLE chat_members ALTER COLUMN notifications_muted DROP DEFAULT;
  END IF;
END
$body$ LANGUAGE plpgsql;

CREATE INDEX IF NOT EXISTS ix_chat_members_user_archived ON chat_members (user_id, is_archived);

-- =============================================================================
-- i9j0k1l2m3n4 — is_pinned в chat_members (чат в списке)
-- =============================================================================
DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'chat_members' AND column_name = 'is_pinned'
  ) THEN
    ALTER TABLE chat_members ADD COLUMN is_pinned BOOLEAN NOT NULL DEFAULT false;
    ALTER TABLE chat_members ALTER COLUMN is_pinned DROP DEFAULT;
  END IF;
END
$body$ LANGUAGE plpgsql;

CREATE INDEX IF NOT EXISTS ix_chat_members_user_pinned ON chat_members (user_id, is_pinned);

-- =============================================================================
-- j2k3l4m5n6o7 — client_message_id + private_pair_key
-- =============================================================================
DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'messages' AND column_name = 'client_message_id'
  ) THEN
    ALTER TABLE messages ADD COLUMN client_message_id VARCHAR(128) NULL;
  END IF;
END
$body$ LANGUAGE plpgsql;

DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname = 'messages' AND c.conname = 'uq_messages_sender_client_message_id'
  ) THEN
    ALTER TABLE messages
      ADD CONSTRAINT uq_messages_sender_client_message_id UNIQUE (sender_id, client_message_id);
  END IF;
END
$body$ LANGUAGE plpgsql;

DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'chats' AND column_name = 'private_pair_key'
  ) THEN
    ALTER TABLE chats ADD COLUMN private_pair_key VARCHAR(64) NULL;
  END IF;
END
$body$ LANGUAGE plpgsql;

UPDATE chats c
SET private_pair_key = pairs.pair_key
FROM (
  SELECT
    cm.chat_id,
    min(cm.user_id)::text || ':' || max(cm.user_id)::text AS pair_key
  FROM chat_members cm
  JOIN chats ch ON ch.id = cm.chat_id
  WHERE ch.type = 'private'
  GROUP BY cm.chat_id
  HAVING count(DISTINCT cm.user_id) = 2
) pairs
WHERE c.id = pairs.chat_id
  AND (c.private_pair_key IS NULL OR c.private_pair_key = '');

DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname = 'chats' AND c.conname = 'uq_chats_private_pair_key'
  ) THEN
    ALTER TABLE chats
      ADD CONSTRAINT uq_chats_private_pair_key UNIQUE (private_pair_key);
  END IF;
END
$body$ LANGUAGE plpgsql;

-- =============================================================================
-- k3l4m5n6o7p8 — закрепы сообщений, опросы, message_mentions
-- =============================================================================
DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'messages' AND column_name = 'pinned_at'
  ) THEN
    ALTER TABLE messages ADD COLUMN pinned_at TIMESTAMP NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'messages' AND column_name = 'pinned_by_user_id'
  ) THEN
    ALTER TABLE messages ADD COLUMN pinned_by_user_id BIGINT NULL;
  END IF;
END
$body$ LANGUAGE plpgsql;

DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname = 'messages' AND c.conname = 'fk_messages_pinned_by_user_id'
  ) THEN
    ALTER TABLE messages
      ADD CONSTRAINT fk_messages_pinned_by_user_id
      FOREIGN KEY (pinned_by_user_id) REFERENCES users (id) ON DELETE SET NULL;
  END IF;
END
$body$ LANGUAGE plpgsql;

CREATE INDEX IF NOT EXISTS ix_messages_chat_pinned ON messages (chat_id, pinned_at);

CREATE TABLE IF NOT EXISTS polls (
  id BIGSERIAL PRIMARY KEY,
  message_id BIGINT NOT NULL UNIQUE REFERENCES messages (id) ON DELETE CASCADE,
  question TEXT NOT NULL,
  allows_multiple BOOLEAN NOT NULL DEFAULT false,
  is_anonymous BOOLEAN NOT NULL DEFAULT false,
  is_closed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS poll_options (
  id BIGSERIAL PRIMARY KEY,
  poll_id BIGINT NOT NULL REFERENCES polls (id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  text TEXT NOT NULL,
  CONSTRAINT uq_poll_options_poll_position UNIQUE (poll_id, position)
);
CREATE INDEX IF NOT EXISTS ix_poll_options_poll_id ON poll_options (poll_id);

CREATE TABLE IF NOT EXISTS poll_votes (
  id BIGSERIAL PRIMARY KEY,
  poll_id BIGINT NOT NULL REFERENCES polls (id) ON DELETE CASCADE,
  option_id BIGINT NOT NULL REFERENCES poll_options (id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_poll_votes_poll_option_user UNIQUE (poll_id, option_id, user_id)
);
CREATE INDEX IF NOT EXISTS ix_poll_votes_poll_id ON poll_votes (poll_id);
CREATE INDEX IF NOT EXISTS ix_poll_votes_option_id ON poll_votes (option_id);
CREATE INDEX IF NOT EXISTS ix_poll_votes_user_id ON poll_votes (user_id);
CREATE INDEX IF NOT EXISTS ix_poll_votes_poll_user ON poll_votes (poll_id, user_id);

CREATE TABLE IF NOT EXISTS message_mentions (
  id BIGSERIAL PRIMARY KEY,
  message_id BIGINT NOT NULL REFERENCES messages (id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT uq_message_mentions_message_user UNIQUE (message_id, user_id)
);
CREATE INDEX IF NOT EXISTS ix_message_mentions_user ON message_mentions (user_id);

-- =============================================================================
-- Опционально: зафиксировать для Alembic «мы на head», чтобы upgrade не трогал
-- (таблица alembic_version обычно уже есть)
-- =============================================================================
-- UPDATE alembic_version SET version_num = 'k3l4m5n6o7p8';
-- если строка одна — UPDATE; если пусто — INSERT:
-- INSERT INTO alembic_version (version_num) SELECT 'k3l4m5n6o7p8'
--   WHERE NOT EXISTS (SELECT 1 FROM alembic_version);
