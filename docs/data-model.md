# Модель данных (кратко)

См. SQLAlchemy-модели в `backend/app/models/` и миграции Alembic в `backend/alembic/versions/`.

## Основные сущности

- **User** — учётная запись, пароль, профиль.
- **Chat** — `type`: `private` | `group`, заголовок, аватар, `created_by`.
- **ChatMember** — связь пользователь ↔ чат, роль (`owner` управляет группой, `member` участвует в чате), `last_read_message_id`.
- **Message** — текст, `message_type`, приватные ключи медиа (`media_key`), ответы и пересылки. `call_event` хранит строки истории звонков в общей ленте сообщений. Для документов `text` содержит отображаемое имя файла; пересылка медиа переиспользует существующий `media_key`.
- **Call** — запись жизненного цикла звонка: `chat_id`, `initiator_id`, `type`, `status`, `started_at`, `accepted_at`, `ended_at`, `duration_seconds`, `client_call_id`.
- **DeviceToken** — push-токены устройств; `is_active=false` означает, что устройство отозвано и не должно получать push.
- **NotificationSetting** — пользовательская настройка доставки push; `notifications_enabled=false` отключает FCM-уведомления для пользователя.
- **PendingRegistration** — верификация email при регистрации.

## Уникальность и связи

- У пары приватного чата участники задаются через `chat_members`; дубликат приватного чата предотвращается в application-слое (`chat_commands`).
- `messages.chat_id` → `chats.id` с каскадным удалением по настройкам БД.

## Индексы

- Составной индекс `ix_messages_chat_id_created_at` на `(chat_id, created_at)` для выборки истории чата (миграция `d1e2f3a4b5c6`).
