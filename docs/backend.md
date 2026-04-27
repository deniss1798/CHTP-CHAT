# Backend

Backend — FastAPI приложение в `backend/app/`.

## Runtime

- Entry point: `app/main.py`.
- API prefix поддерживает оба варианта: без префикса и с `/api`.
- Конфигурация: `app/core/config.py`, переменные окружения описаны в [env.md](env.md).
- База: SQLAlchemy models в `app/models/`, Alembic migrations в `backend/alembic/versions/`.

## Слои

- `api/` принимает HTTP/WebSocket запросы, связывает зависимости и вызывает application-функции.
- `application/` содержит сценарии auth, chats, messages, media, realtime.
- `domain/` хранит политики доступа и бизнес-правила без transport-зависимостей.
- `repositories/` изолирует повторяемые DB-запросы.
- `infrastructure/` содержит внешние адаптеры: S3, media pipeline, TURN.
- `core/` содержит безопасность, rate limits, push, config, logging.

## Основные роутеры

- `auth_router.py` — регистрация, login, короткоживущий `ws_token`.
- `users_router.py` — профиль текущего пользователя.
- `chats_router.py` и `api/routers/chats/` — создание и управление чатами.
- `api/routers/messages/` — текст, медиа, реакции, read state, forward/edit/delete.
- `devices_router.py` — активные устройства и отзыв push-токенов.
- `notification_settings_router.py` — настройка push.
- `ws_router.py`, `ws_inbox_router.py` — realtime.
- `webrtc_router.py` — ICE/TURN config для звонков.

## Health и наблюдаемость (этап 12)

- `GET /health` — liveness: процесс отвечает, без проверки БД.
- `GET /ready` и `GET /api/ready` — readiness: `SELECT 1` к БД; при недоступности БД — **503** с `detail: not_ready` (k8s `readinessProbe`).
- Каждая HTTP-реакция с заголовком **`X-Request-ID`**: клиент может прислать свой в заголовке (до 128 символов) или сервер сгенерирует UUID. Заголовок дублируется в ответе; при `PERF_LOG_REQUESTS` поле `request_id` попадает в JSON-лог `perf` (вместе с `X-Response-Time-Ms`). CORS, если включён, отдаёт `expose_headers` для `X-Request-ID` и `X-Response-Time-Ms`, чтобы фронт мог читать их из `fetch`.

## Проверки

```powershell
cd backend
python -m pytest tests/ -q
python -m alembic heads
```
