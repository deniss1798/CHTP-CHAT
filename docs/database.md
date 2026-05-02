# Database

Основная база — PostgreSQL. ORM-модели находятся в `backend/app/models/`, миграции — в `backend/alembic/versions/`.

## Миграции

```powershell
cd backend
alembic upgrade head
python -m alembic heads
```

Новая схема должна попадать в Alembic migration. Если миграции нельзя применить автоматически, SQL из migration можно выполнить напрямую в БД после ревью.

## Основные Таблицы

- `users` — аккаунты и профиль.
- `pending_registrations` — email verification flow; verification code хранится в hashed виде.
- `chats` — private/group chats.
- `chat_members` — участники, роли, read state.
- `messages` — сообщения, media metadata, reply/forward/edit/delete state.
- `message_reactions` — реакции пользователей.
- `device_tokens` — push-токены устройств.
- `notification_settings` — настройки доставки push.
- `calls` — жизненный цикл звонков.

## Индексы

Критичные query paths:

- `messages(chat_id, id)` для cursor pagination и reconnect recovery.
- `messages(chat_id, created_at, id)` для истории и сортировки.
- `chat_members(user_id, chat_id)` для списка чатов пользователя.
- `calls(chat_id)`, `calls(status)`, `calls(initiator_id)` для будущей истории звонков.

## Правила

- Не отдавать internal storage keys клиенту: `media_key` не является публичным контрактом.
- Для private media клиент получает временный `media_url`.
- Soft delete сообщений оставляет tombstone в истории.
- Новые стабильные поля должны быть backward-compatible optional, если уже есть клиенты в проде.