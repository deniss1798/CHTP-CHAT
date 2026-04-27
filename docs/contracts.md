# Contracts

Канонические transport-контракты, на которые должны ориентироваться backend и Flutter-клиент.

## REST

### Auth

`POST /auth/request-email-code`

Создаёт pending registration и отправляет email-код.

`POST /auth/verify-email-code`

Проверяет код, создаёт пользователя и возвращает `TokenResponse`.

`POST /auth/login`

Проверяет email/password и возвращает `TokenResponse`.

`POST /auth/ws-token`

Требует обычный `Authorization: Bearer <access_token>` и возвращает короткоживущий токен для WebSocket:

- `ws_token`
- `expires_in`: сейчас 60 секунд

Flutter должен использовать `ws_token` в query string WebSocket вместо долгоживущего access token. Backend временно принимает оба формата для совместимости.

Auth endpoints защищены базовым in-memory rate-limit:

- login: 5 попыток / 10 минут / IP + email;
- request email code: 3 попытки / 10 минут / IP + email;
- verify email code: 5 попыток / 10 минут / IP + email.

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

Для групповых управляющих операций (`POST /chats/{chat_id}/members`, `DELETE /chats/{chat_id}/members/{user_id}`, переименование и аватар группы) текущий пользователь должен быть участником с `role=owner`.

### `GET /chats/{chat_id}/read-state`

Возвращает `MemberReadState[]`:

- `user_id`
- `last_read_message_id`

### `POST /chats/`

Создаёт чат. Тело:

- `type`: `private | group`
- `title` optional для private, required для group
- `member_ids`

### `POST /chats/{chat_id}/members`

Добавляет участника в группу. Требуется `role=owner`.

Тело:

- `user_id`

### `POST /chats/{chat_id}/leave`

Текущий пользователь выходит из группы.

### `DELETE /chats/{chat_id}/members/{member_user_id}`

Удаляет участника из группы. Требуется `role=owner`.

### `POST /messages/`

Отправка текста или системной строки звонка. Ответ: `MessageResponse`.
Endpoint защищён базовым in-memory rate-limit: 60 сообщений / минуту / user.

Тело:

- `chat_id`
- `text`
- `reply_to_message_id` optional
- `message_type`: optional, `text | call_event`; по умолчанию `text`

`call_event` используется для строк истории звонков (`Пропущенный вызов`, `Вызов завершён · 03:06`, `Вызов отменён`) и не поддерживает reply.

### `GET /messages/chat/{chat_id}`

Возвращает страницу истории сообщений. Доступ есть только у участников чата.

Query:

- `before_message_id` optional
- `after_message_id` optional
- `limit` optional, максимум 100

### `PATCH /messages/{message_id}`

Редактирует текстовое сообщение отправителя.

### `DELETE /messages/{message_id}`

Мягко удаляет сообщение отправителя: в истории остаётся tombstone `Сообщение удалено`.

### `POST /messages/forward`

Пересылает сообщение в другой чат, где текущий пользователь является участником.

### `POST /messages/{message_id}/reactions`

Добавляет реакцию текущего пользователя.

### `DELETE /messages/{message_id}/reactions`

Удаляет реакцию текущего пользователя.

### `POST /messages/photo|video|video-note|video_note|voice|document|file`

Отправка медиа. Ответ: `MessageResponse`.

Форма:

- `chat_id`
- `file`
- `reply_to_message_id` optional

Типы сообщений в ответе:

- `image` для `/photo`;
- `video` для `/video`;
- `video_note` для `/video-note` и `/video_note`;
- `voice` для `/voice`;
- `document` для `/document` и `/file`.

Для приватных медиа `media_url` является временным presigned URL. `media_key` не является публичной ссылкой. Для документов отображаемое имя файла лежит в `text`.

### `GET /users/`

Поиск пользователей (пагинация). Query: `q`, `limit`, `cursor`.

Ответ `UserSearchPage`: `users: UserResponse[]`, `has_more`, `next_cursor` (nullable). Клиенту допустимо ожидать и легаси-формат «плоский массив users» (совместимость).

### `GET /calls`

История звонков текущего пользователя. Query: `chat_id` (optional), `limit`, `cursor`. Ответ: страница с `calls`, `has_more`, `next_cursor`.

### `GET /devices`

Возвращает устройства текущего пользователя. Query: `limit`, `cursor`.

Ответ `DeviceListPage`: `devices: DeviceTokenResponse[]`, `has_more`, `next_cursor`. Элемент `devices[]`:

- `id`
- `platform`
- `device_name`
- `is_active`
- `created_at`
- `updated_at`

### `DELETE /devices/{device_id}`

Отключает push-токен устройства текущего пользователя (`is_active=false`). Чужие устройства возвращают `404`.

### `DELETE /devices`

Отключает все push-токены текущего пользователя (`is_active=false`).

### `GET /notification-settings`

Возвращает настройки уведомлений текущего пользователя:

- `notifications_enabled`
- `created_at`
- `updated_at`

Если запись отсутствует, сервер создаёт настройки по умолчанию с `notifications_enabled=true`.

### `PUT /notification-settings`

Обновляет настройки уведомлений текущего пользователя.

Тело:

- `notifications_enabled`: `bool`

Когда `notifications_enabled=false`, backend не отправляет FCM push на устройства пользователя.

### `GET /webrtc/ice-config`

Возвращает WebRTC ICE configuration для клиента:

- `ice_servers`
- `ttl_seconds`
- `expires_at`

Если TURN не настроен, возвращаются fallback STUN servers.

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

Call lifecycle statuses: `created`, `ringing`, `accepted`, `declined`, `cancelled`, `missed`, `ended`, `failed`, `expired`. Разрешённые переходы фиксируются state machine: terminal statuses (`declined/cancelled/missed/ended/failed/expired`) не могут перейти обратно в `accepted`.

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
