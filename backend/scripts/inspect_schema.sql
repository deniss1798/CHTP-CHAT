-- Снимок схемы public для мессенджера: без дампа, только метаданные.
-- DBeaver: открой файл, выбери нужную БД, выполни целиком (Ctrl+Enter по выделению) или по секциям.

-- -----------------------------------------------------------------------------
-- 0) Контекст
-- -----------------------------------------------------------------------------
SELECT current_database() AS db, current_user AS db_user, current_schema() AS schema;

-- -----------------------------------------------------------------------------
-- 1) Таблицы из списка, которые реально есть
-- -----------------------------------------------------------------------------
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
  AND table_name IN (
    'messages', 'chats', 'chat_members', 'users',
    'stories', 'story_views', 'calls',
    'polls', 'poll_options', 'poll_votes',
    'message_mentions', 'message_reactions',
    'notification_settings', 'device_tokens', 'pending_registrations',
    'alembic_version'
  )
ORDER BY table_name;

-- -----------------------------------------------------------------------------
-- 2) Колонки (тип, null, default)
-- -----------------------------------------------------------------------------
SELECT
  c.table_name,
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.character_maximum_length,
  c.numeric_precision,
  c.numeric_scale,
  c.is_nullable,
  c.column_default
FROM information_schema.columns c
WHERE c.table_schema = 'public'
  AND c.table_name IN (
    'messages', 'chats', 'chat_members', 'users',
    'stories', 'story_views', 'calls',
    'polls', 'poll_options', 'poll_votes',
    'message_mentions', 'message_reactions',
    'notification_settings', 'device_tokens', 'pending_registrations',
    'alembic_version'
  )
ORDER BY c.table_name, c.ordinal_position;

-- -----------------------------------------------------------------------------
-- 3) Первичные ключи и UNIQUE
-- -----------------------------------------------------------------------------
SELECT
  tc.table_name,
  tc.constraint_type,
  tc.constraint_name,
  string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_schema = kcu.constraint_schema
 AND tc.constraint_name = kcu.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
  AND tc.table_name IN (
    'messages', 'chats', 'chat_members', 'users',
    'stories', 'story_views', 'calls',
    'polls', 'poll_options', 'poll_votes',
    'message_mentions', 'message_reactions',
    'notification_settings', 'device_tokens', 'pending_registrations',
    'alembic_version'
  )
GROUP BY tc.table_name, tc.constraint_type, tc.constraint_name
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

-- -----------------------------------------------------------------------------
-- 4) Внешние ключи
-- -----------------------------------------------------------------------------
SELECT
  tc.table_name,
  tc.constraint_name,
  kcu.column_name,
  ccu.table_name AS references_table,
  ccu.column_name AS references_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_schema = kcu.constraint_schema
 AND tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_schema = tc.constraint_schema
 AND ccu.constraint_name = tc.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name IN (
    'messages', 'chats', 'chat_members', 'users',
    'stories', 'story_views', 'calls',
    'polls', 'poll_options', 'poll_votes',
    'message_mentions', 'message_reactions',
    'notification_settings', 'device_tokens', 'pending_registrations',
    'alembic_version'
  )
ORDER BY tc.table_name, tc.constraint_name, kcu.ordinal_position;

-- -----------------------------------------------------------------------------
-- 5) Индексы (включая уникальные как индексы)
-- -----------------------------------------------------------------------------
SELECT
  t.relname AS table_name,
  i.relname AS index_name,
  ix.indisunique AS is_unique,
  pg_get_indexdef(i.oid) AS index_def
FROM pg_class t
JOIN pg_index ix ON t.oid = ix.indrelid
JOIN pg_class i ON i.oid = ix.indexrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE n.nspname = 'public'
  AND t.relkind = 'r'
  AND NOT ix.indisprimary
  AND t.relname IN (
    'messages', 'chats', 'chat_members', 'users',
    'stories', 'story_views', 'calls',
    'polls', 'poll_options', 'poll_votes',
    'message_mentions', 'message_reactions',
    'notification_settings', 'device_tokens', 'pending_registrations',
    'alembic_version'
  )
ORDER BY 1, 2;

-- -----------------------------------------------------------------------------
-- 6) CHECK-ограничения (если есть)
-- -----------------------------------------------------------------------------
SELECT
  tc.table_name,
  tc.constraint_name,
  cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc
  ON tc.constraint_schema = cc.constraint_schema
 AND tc.constraint_name = cc.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.constraint_type = 'CHECK'
  AND tc.table_name IN (
    'messages', 'chats', 'chat_members', 'users',
    'stories', 'story_views', 'calls',
    'polls', 'poll_options', 'poll_votes',
    'message_mentions', 'message_reactions',
    'notification_settings', 'device_tokens', 'pending_registrations',
    'alembic_version'
  )
ORDER BY tc.table_name, tc.constraint_name;

-- -----------------------------------------------------------------------------
-- 7) Alembic (только если таблица public.alembic_version существует)
-- -----------------------------------------------------------------------------
DO $body$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'alembic_version'
  ) THEN
    RAISE NOTICE 'alembic_version: %', (SELECT string_agg(version_num, ', ') FROM public.alembic_version);
  ELSE
    RAISE NOTICE 'alembic_version: таблицы нет';
  END IF;
END
$body$ LANGUAGE plpgsql;
