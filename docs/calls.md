# Звонки (WebRTC)

## Backend

- **Сигналинг и TURN**: `backend/app/api/webrtc_router.py`.
- Учётные данные TURN: `backend/app/infrastructure/turn/turn_credentials.py`.

## Клиент

- Flutter: `mobile_app/lib/features/calls/` — сессии звонка, ICE, экраны `voice_call_screen`, `group_call_screen`.

## Статусы

Состояния сессии описаны в коде сессий на клиенте (`voice_call_session`, `group_call_session`); при расширении API имеет смысл вынести enum в `application/calls/` на сервере.
