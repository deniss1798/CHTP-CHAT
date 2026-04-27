# API

Канонический контракт REST описан в [contracts.md](contracts.md). Этот документ даёт карту API по доменам и правила совместимости.

## Auth

- `POST /auth/request-email-code` — запрос email-кода.
- `POST /auth/verify-email-code` — проверка кода и создание пользователя.
- `POST /auth/login` — login по email/password.
- `POST /auth/ws-token` — короткоживущий токен для WebSocket.

Auth endpoints rate-limited по IP и email. Email-коды генерируются криптографически стойко и хранятся hashed.

## Users

- `GET /users/me` — текущий пользователь.
- Profile endpoints должны требовать Bearer JWT.

## Chats

- `GET /chats/` — список чатов текущего пользователя.
- `POST /chats/` — создание private/group chat.
- `GET /chats/{chat_id}` — детали чата.
- `GET /chats/{chat_id}/members` — участники.
- `POST /chats/{chat_id}/members` — добавить участника в группу.
- `DELETE /chats/{chat_id}/members/{user_id}` — удалить участника.
- `POST /chats/{chat_id}/leave` — выйти из группы.

Group management требует роль `owner`.

## Messages

- `POST /messages/` — text и `call_event`.
- `GET /messages/chat/{chat_id}` — история с `before_message_id`/`after_message_id`.
- `PATCH /messages/{message_id}` — edit text.
- `DELETE /messages/{message_id}` — soft delete.
- `POST /messages/forward` — forward.
- `POST /messages/{message_id}/reactions` — добавить reaction.
- `DELETE /messages/{message_id}/reactions` — удалить reaction.

Media upload endpoints:

- `POST /messages/photo`
- `POST /messages/video`
- `POST /messages/video-note`
- `POST /messages/video_note`
- `POST /messages/voice`
- `POST /messages/document`
- `POST /messages/file`

## Devices And Notifications

- `GET /devices` — список устройств.
- `DELETE /devices/{device_id}` — отозвать одно устройство.
- `DELETE /devices` — отозвать все устройства текущего пользователя.
- `GET /notification-settings` — получить настройки push.
- `PUT /notification-settings` — обновить настройки push.

## WebRTC

- `GET /webrtc/ice-config` — STUN/TURN `iceServers` для клиента.

## Compatibility Rules

- Новые поля добавляются как optional.
- Изменение payload shape требует обновить backend schemas, Flutter mappers, `contracts.md` и тесты.
- Ошибки должны возвращаться в едином FastAPI формате с понятным `detail`.
