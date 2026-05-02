# Звонки (WebRTC)

## Backend

- **Сигналинг и TURN**: `backend/app/api/webrtc_router.py`.
- Учётные данные TURN: `backend/app/infrastructure/turn/turn_credentials.py`.
- **Call lifecycle storage**: `backend/app/models/call.py`, таблица `calls`.

## Клиент

- Flutter: `mobile_app/lib/features/calls/` — сессии звонка, ICE, экраны `voice_call_screen`, `group_call_screen`.

## Статусы

Состояния звонка:

- `created`;
- `ringing`;
- `accepted`;
- `declined`;
- `cancelled`;
- `missed`;
- `ended`;
- `failed`;
- `expired`.

Terminal statuses (`declined`, `cancelled`, `missed`, `ended`, `failed`, `expired`) не переходят обратно в `accepted`.

## Сообщения В Чате

История звонков попадает в чат как `message_type: "call_event"`:

- `Пропущенный вызов`;
- `Вызов завершён · 03:06`;
- `Вызов отменён`;
- `Звонок отклонён`.

## Групповые Звонки

- Host завершает общий звонок через `group_call_end`.
- Обычный участник выходит через `group_call_leave`.
- SDP/ICE не дублируются в inbox, чтобы клиент не применял один WebRTC payload дважды.
