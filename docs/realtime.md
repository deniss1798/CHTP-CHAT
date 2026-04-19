# Realtime (WebSocket)

## Backend

- **Менеджеры**: `app/core/ws_manager.py` — доставка в комнаты чата и inbox-персональные каналы.
- **Роутеры WS**: `app/api/ws_router.py`, `app/api/ws_inbox_router.py`.

## Имена событий (контракт)

Константы для согласования с клиентами: `app/application/realtime/ws_event_names.py`.

- Новое сообщение в чате: payload с `"type": "new_message"` и полем `message` (см. `build_message_payload` в `application/messages/message_projection.py`).
- Обновление / удаление: `application/realtime/chat_events.py` (`publish_message_updated`, `publish_message_deleted`); новые сообщения — `publish_new_message`.

## Inbox

После отправки сообщения вызывается `notify_inbox_new_message` (`application/messages/inbox_delivery.py`) для пользователей, не являющихся отправителем.
