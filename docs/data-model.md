# Модель данных (кратко)

См. SQLAlchemy-модели в `backend/app/models/` и миграции Alembic в `backend/alembic/versions/`.

## Основные сущности

- **User** — учётная запись, пароль, профиль.
- **Chat** — `type`: `private` | `group`, заголовок, аватар, `created_by`.
- **ChatMember** — связь пользователь ↔ чат, роль, `last_read_message_id`.
- **Message** — текст, `message_type`, приватные ключи медиа (`media_key`), ответы и пересылки.
- **DeviceToken** — push-токены устройств.
- **PendingRegistration** — верификация email при регистрации.

## Уникальность и связи

- У пары приватного чата участники задаются через `chat_members`; дубликат приватного чата предотвращается в application-слое (`chat_commands`).
- `messages.chat_id` → `chats.id` с каскадным удалением по настройкам БД.

## Индексы

- Составной индекс `ix_messages_chat_id_created_at` на `(chat_id, created_at)` для выборки истории чата (миграция `d1e2f3a4b5c6`).
