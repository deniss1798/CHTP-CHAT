# Backend

FastAPI backend для Messanger.

## Что здесь есть

- REST API для auth, users, chats, messages, devices
- WebSocket realtime для чатов и inbox
- media upload / private media URLs
- WebRTC signaling и TURN credentials
- PostgreSQL + Alembic migrations

## Структура

- `app/api/` — HTTP и WebSocket endpoints
- `app/application/` — use cases
- `app/domain/` — policies и бизнес-правила
- `app/repositories/` — доступ к данным
- `app/infrastructure/` — storage, media, turn
- `app/core/` — config, security, shared services
- `tests/` — unit/integration tests

## Конфигурация

Создайте локальный `backend/.env` на основе `backend/.env.example`.

Ключевые настройки:

- `DATABASE_URL`
- `SECRET_KEY`
- `SMTP_*`
- `CORS_ORIGINS`
- `TURN_*`
- `WEBRTC_FALLBACK_STUN_URLS`

Секреты и реальные ключи не должны попадать в git.

## Локальный запуск

```powershell
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload
```

## Тесты

```powershell
cd backend
pytest
```

## Архитектурные правила

См. [../docs/architecture-rules.md](../docs/architecture-rules.md)

## Контракты

Канонические REST / WebSocket payloads описаны в [../docs/contracts.md](../docs/contracts.md)
