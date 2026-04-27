# Environment

Backend читает настройки через `backend/app/core/config.py`. Локально значения обычно лежат в `backend/.env`.

## Required Backend Variables

- `DATABASE_URL` — PostgreSQL connection string.
- `SECRET_KEY` — ключ подписи JWT.
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- `SMTP_PASSWORD`
- `SMTP_FROM`

## Optional Backend Variables

- `PERF_LOG_REQUESTS` / `perf_log_requests` — если `true`, логирует длительность HTTP-запросов (JSON, поле `request_id` при наличии `X-Request-ID` / middleware) и выставляет заголовок `X-Response-Time-Ms`.
- `ALGORITHM` — алгоритм JWT, по умолчанию `HS256`.
- `ACCESS_TOKEN_EXPIRE_MINUTES` — срок жизни access token.
- `CORS_ORIGINS` — список origins через запятую.
- `FIREBASE_SERVICE_ACCOUNT_FILE` — путь к Firebase service account.
- `FIREBASE_SERVICE_ACCOUNT_JSON` — JSON credentials как строка.

## S3 / Media

Можно использовать `S3_*` или совместимые `AWS_*` переменные:

- `S3_ENDPOINT_URL` или `AWS_ENDPOINT_URL`
- `S3_REGION` или `AWS_DEFAULT_REGION`
- `S3_ACCESS_KEY_ID` или `AWS_ACCESS_KEY_ID`
- `S3_SECRET_ACCESS_KEY` или `AWS_SECRET_ACCESS_KEY`
- `S3_PUBLIC_BUCKET`
- `S3_PRIVATE_BUCKET`
- `S3_PUBLIC_BASE_URL`

Private media требует `S3_PRIVATE_BUCKET`. Public avatars требуют `S3_PUBLIC_BUCKET` и `S3_PUBLIC_BASE_URL`.

## WebRTC / TURN

- `TURN_STATIC_AUTH_SECRET` — coturn static auth secret.
- `TURN_SERVER_HOST` — публичный hostname/IP TURN.
- `TURN_UDP_PORT` — по умолчанию `3478`.
- `TURN_TLS_PORT` — optional TLS port.
- `TURN_CREDENTIAL_TTL_SECONDS` — TTL временных TURN credentials.
- `WEBRTC_FALLBACK_STUN_URLS` — fallback STUN servers.

## Flutter Dart Defines

- `API_BASE_URL` — backend API base URL, например `http://127.0.0.1:8000/api`.
- `WEBRTC_FORCE_RELAY` — debug flag для TURN-only проверки звонков.

Пример:

```powershell
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```
