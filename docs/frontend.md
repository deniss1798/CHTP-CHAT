# Frontend

Flutter-клиент находится в `mobile_app/` и поддерживает мобильный интерфейс и desktop layout.

## Runtime

- API base URL задаётся через `--dart-define=API_BASE_URL=...`.
- REST transport: `lib/core/network/api_client.dart`.
- Chat WebSocket contract: `lib/core/realtime/chat_ws_contract.dart`.
- Short-lived WebSocket tokens: `lib/core/realtime/ws_token_service.dart`.

## Feature Layout

- `features/chats/` — список чатов, детали, composer, media, realtime controllers.
- `features/calls/` — 1:1 и group WebRTC sessions, call screens, call state machine.
- `features/settings/` — настройки, активные устройства, notification preferences.
- `app/theme/` и `core/theme/` — design tokens, colors, typography, icons, shadows.
- `app/widgets/` — reusable UI: buttons, fields, cards, avatars, surfaces.

## State And Realtime

- Большие экраны декомпозируются на `screen + controller + widgets`.
- Realtime events дедуплицируются по `event_id`, fallback — по типу события и message id.
- После reconnect чат догружает сообщения через `after_message_id`.
- Outgoing text messages используют optimistic UI с `client_temp_id` и `delivery_status`.

## Проверки

```powershell
cd mobile_app
flutter analyze
flutter test
```
