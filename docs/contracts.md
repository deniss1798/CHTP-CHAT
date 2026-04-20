# Contracts

Канонические transport-контракты, на которые должны ориентироваться backend и Flutter-клиент.

## REST

### `GET /chats/`

Возвращает список `ChatResponse[]`:

- `id`
- `type`: `private | group`
- `title`
- `avatar_url`
- `created_by`
- `last_message`
- `last_message_type`
- `last_message_at`
- `last_message_sender_id`
- `last_message_id`
- `my_last_read_message_id`
- `unread_count`
- `peer_last_seen_at`

### `GET /chats/{chat_id}`

Возвращает `ChatDetailResponse`:

- `id`
- `type`
- `title`
- `avatar_url`
- `created_by`
- `members[]`

Элемент `members[]`:

- `id`
- `username`
- `email`
- `avatar_url`
- `last_seen_at`

### `GET /chats/{chat_id}/members`

Возвращает `ChatMemberResponse[]`:

- `id`
- `username`
- `email`
- `avatar_url`
- `role`
- `last_seen_at`

### `GET /chats/{chat_id}/read-state`

Возвращает `MemberReadState[]`:

- `user_id`
- `last_read_message_id`

### `POST /messages/`

Отправка текста. Ответ: `MessageResponse`.

### `POST /messages/photo|video|video-note|document`

Отправка медиа. Ответ: `MessageResponse`.

## WebSocket чата

Маршрут: `GET /ws/chat/{chat_id}?token=...`

### Входящие события

- `{"type":"new_message","message":{...}}`
- `{"event":"message_updated","message":{...}}`
- `{"event":"message_deleted","id":123,"chat_id":456}`
- `{"type":"read_receipt","chat_id":456,"user_id":42,"last_read_message_id":123}`
- `{"type":"typing","chat_id":456,"user_id":42,"username":"alice","typing":true}`

### Исходящие события от клиента

- `{"type":"typing","typing":true|false}`
- сигнальные call events: `call_e2e_*`, `group_call_*`

## Inbox WebSocket

Маршрут: `GET /ws/inbox?token=...`

### Входящие события

- `{"type":"inbox_new_message","chat_id":"456","sender_name":"alice","preview":"Привет","chat_avatar_url":"..."}`
- `{"type":"typing","chat_id":456,"user_id":42,"username":"alice","typing":true}`
- `call_e2e_*` и `group_call_*` для входящих звонков

### Ping / pong

- клиент отправляет `{"type":"ping"}`
- сервер отвечает `{"type":"pong"}`

## Правила совместимости

- Новые поля можно добавлять только как backward-compatible optional.
- Переименование transport-полей требует синхронного обновления backend, mobile DTO/mappers и этой документации.
- Если event name или payload shape меняется, нужно обновить общий контрактный слой (`ChatWsContract` и backend constants) в одном коммите.
