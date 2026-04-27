# ЧТП ЧАТ

ЧТП ЧАТ — кроссплатформенный мессенджер с Flutter-клиентом и FastAPI backend. В проекте есть личные и групповые чаты, realtime через WebSocket, push-уведомления, приватные медиа, реакции, replies/forward/edit/delete, активные устройства, настройки уведомлений и WebRTC-звонки.

## Стек

- **Mobile/Desktop**: Flutter, Dart, Dio, Firebase Messaging, `flutter_webrtc`.
- **Backend**: FastAPI, SQLAlchemy, Alembic, PostgreSQL.
- **Realtime**: WebSocket chat/inbox channels, short-lived `ws_token`, event deduplication.
- **Media**: S3-compatible storage, private presigned URLs, MIME/signature validation.
- **Security**: JWT, hashed email verification codes, rate limits, log redaction, security headers.

## Структура

- `backend/` — FastAPI API, application layer, repositories, models, Alembic migrations, tests.
- `mobile_app/` — Flutter приложение, feature modules, reusable app widgets, tests.
- `docs/` — архитектура, API, realtime, media, calls, security, deployment и env contracts.

## Запуск Backend

```powershell
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload
```

Backend читает настройки из `backend/.env`. Минимально нужны `DATABASE_URL`, `SECRET_KEY`, SMTP-переменные для регистрации по email и `CORS_ORIGINS`. Полный список описан в [docs/env.md](docs/env.md).

## Запуск Flutter

```powershell
cd mobile_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Для production передай реальный `API_BASE_URL`. Windows release-сборку можно запускать из корня через `build_flutter_release.bat`.

## Тесты

```powershell
cd backend
python -m pytest tests/ -q
```

```powershell
cd mobile_app
flutter analyze
flutter test
```

## Документация

- [Architecture](docs/architecture.md)
- [Backend](docs/backend.md)
- [Frontend](docs/frontend.md)
- [Database](docs/database.md)
- [API](docs/api.md)
- [Contracts](docs/contracts.md)
- [Realtime](docs/realtime.md)
- [Media](docs/media.md)
- [Calls](docs/calls.md)
- [Security](docs/security.md)
- [Testing](docs/testing.md)
- [Deployment](docs/deployment.md)
- [Env](docs/env.md)
- [Architecture Rules](docs/architecture-rules.md)
