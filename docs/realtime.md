# Realtime (WebSocket)

## Backend

- **Менеджеры**: `app/core/ws_manager.py` — доставка в комнаты чата и inbox-персональные каналы.
- **Роутеры WS**: `app/api/ws_router.py`, `app/api/ws_inbox_router.py`.

## Авторизация

Клиент получает короткоживущий токен через `POST /auth/ws-token` и подключается:

- `/ws/chat/{chat_id}?token=<ws_token>`
- `/ws/inbox?token=<ws_token>`

`ws_token` живёт 60 секунд и нужен только для установления соединения. Для совместимости backend временно принимает обычный access token, но новые клиенты должны использовать `ws_token`.

## Имена событий (контракт)

Константы для согласования с клиентами: `app/application/realtime/ws_event_names.py`.

- Каждое realtime-событие содержит metadata:
  - `event_id`: строка, уникальный id доставки события;
  - `occurred_at`: ISO-8601 UTC-время создания события.
- Клиент обязан дедуплицировать события по `event_id`. Для старых payload без `event_id` допустим fallback по типу события и `message.id`.
- Новое сообщение в чате: payload с `"type": "new_message"` и полем `message` (см. `build_message_payload` в `application/messages/message_projection.py`).
- Typing: payload с `"type": "typing"`.
- Read receipt: payload с `"type": "read_receipt"`, `user_id` и `last_read_message_id`.
- Обновление / удаление: `application/realtime/chat_events.py` (`publish_message_updated`, `publish_message_deleted`); новые сообщения — `publish_new_message`.

## WebSocket Events

### `new_message`

- Direction: server -> client.
- Payload: `event_id`, `occurred_at`, `type: "new_message"`, `message`.
- When: после создания text/media/call_event сообщения.
- Client reaction: дедуплицировать по `event_id`, добавить или заменить сообщение в списке.

```json
{
  "event_id": "uuid",
  "occurred_at": "2026-04-27T18:00:00Z",
  "type": "new_message",
  "message": { "id": 123, "chat_id": 10, "message_type": "text", "text": "Привет" }
}
```

### `message_updated`

- Direction: server -> client.
- Payload: `event_id`, `occurred_at`, `event: "message_updated"`, `message`.
- When: автор отредактировал текстовое сообщение.
- Client reaction: найти сообщение по `message.id` и заменить payload.

```json
{
  "event_id": "uuid",
  "occurred_at": "2026-04-27T18:00:00Z",
  "event": "message_updated",
  "message": { "id": 123, "chat_id": 10, "text": "Обновлено", "is_updated": true }
}
```

### `message_deleted`

- Direction: server -> client.
- Payload: `event_id`, `occurred_at`, `event: "message_deleted"`, `id`, `chat_id`.
- When: автор soft-delete сообщения.
- Client reaction: заменить сообщение tombstone-строкой `Сообщение удалено`.

```json
{
  "event_id": "uuid",
  "occurred_at": "2026-04-27T18:00:00Z",
  "event": "message_deleted",
  "id": 123,
  "chat_id": 10
}
```

### `read_receipt`

- Direction: server -> client.
- Payload: `type: "read_receipt"`, `chat_id`, `user_id`, `last_read_message_id`.
- When: участник обновил read state.
- Client reaction: пересчитать delivery status сообщений.

```json
{
  "type": "read_receipt",
  "chat_id": 10,
  "user_id": 2,
  "last_read_message_id": 123
}
```

### `typing`

- Direction: client -> server and server -> client.
- Payload: `type: "typing"`, `typing`, plus server fields `chat_id`, `user_id`, `username`.
- When: пользователь начал или закончил печатать.
- Client reaction: показать или скрыть typing indicator.

```json
{ "type": "typing", "typing": true }
```

### `inbox_new_message`

- Direction: server -> client on inbox WebSocket.
- Payload: `event_id`, `occurred_at`, `type`, `chat_id`, `sender_name`, `preview`, `chat_avatar_url`.
- When: новое сообщение пришло в чат, который может быть не открыт на клиенте.
- Client reaction: обновить список чатов, показать local notification если чат не активен.

```json
{
  "event_id": "uuid",
  "occurred_at": "2026-04-27T18:00:00Z",
  "type": "inbox_new_message",
  "chat_id": "10",
  "sender_name": "alice",
  "preview": "Привет",
  "chat_avatar_url": null
}
```

### Call Signaling

- Direction: client -> server and server -> client.
- 1:1 types: `call_e2e_init`, `call_e2e_ack`, `call_e2e_offer`, `call_e2e_answer`, `call_e2e_ice`, `call_e2e_hangup`.
- Group types: `group_call_invite`, `group_call_join`, `group_call_sdp`, `group_call_ice`, `group_call_leave`, `group_call_end`.
- Payload: `type`, `call_id`, call-specific fields like `payload`, `ephem_pub_b64`, `to_user_id`, `started_by`, `video`.
- When: WebRTC session setup, ICE exchange, hangup, group call join/leave/end.
- Client reaction: route event to active call session by `call_id`; ignore duplicate SDP/ICE from inbox when chat socket is active.

```json
{
  "type": "call_e2e_init",
  "call_id": "client-generated-id",
  "ephem_pub_b64": "base64"
}
```

### `ping` / `pong`

- Direction: client -> server and server -> client on inbox WebSocket.
- Payload: `type: "ping"` or `type: "pong"`.
- When: keepalive.
- Client reaction: keep socket marked healthy.

```json
{ "type": "ping" }
```

## Reconnect recovery

После переподключения клиент запрашивает пропущенные сообщения:

```text
GET /messages/chat/{chat_id}?after_message_id=<last_known_message_id>&limit=100
```

Ответ имеет тот же формат `MessageListPage`, что и обычная загрузка истории. Клиент добавляет только отсутствующие сообщения по `message.id`, чтобы reconnect не создавал дубли.

## Optimistic messages

Исходящее текстовое сообщение сразу добавляется в UI с `client_temp_id` и `delivery_status: "sending"`.

- При успешном REST-ответе временное сообщение заменяется серверным `message.id`.
- При ошибке статус становится `delivery_status: "failed"`.
- Пользователь может повторить отправку, после чего тот же `client_temp_id` снова переходит в `sending` и заменяется серверным сообщением при успехе.

## Inbox

После отправки сообщения вызывается `notify_inbox_new_message` (`application/messages/inbox_delivery.py`) для пользователей, не являющихся отправителем.

Подробный канонический контракт см. в [contracts.md](contracts.md).

## Calls

Call signaling uses the chat WebSocket and is kept separate from persisted chat messages:

- 1:1 encrypted signaling: `call_e2e_init`, `call_e2e_ack`, `call_e2e_offer`, `call_e2e_answer`, `call_e2e_ice`, `call_e2e_hangup`.
- Group call mesh signaling: `group_call_invite`, `group_call_join`, `group_call_sdp`, `group_call_ice`, `group_call_leave`, `group_call_end`.
- SDP/ICE events are not duplicated into inbox delivery to avoid double WebRTC handling on clients with both chat and inbox sockets open.

Call lifecycle statuses are fixed as `created`, `ringing`, `accepted`, `declined`, `cancelled`, `missed`, `ended`, `failed`, `expired`. Terminal statuses cannot transition back to `accepted`. Chat history uses `message_type: "call_event"` for system lines such as `Пропущенный вызов`, `Вызов завершён · 03:06`, and `Вызов отменён`.
