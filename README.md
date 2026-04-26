# Messanger

Кроссплатформенный мессенджер: Flutter-клиент (`mobile_app/`) и FastAPI backend (`backend/`) с чатами, WebSocket realtime, медиа, push и звонками.

## Backend

```powershell
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload
```

Основные env: `DATABASE_URL`, `SECRET_KEY`, `CORS_ORIGINS`, SMTP-переменные для email, `S3_ENDPOINT_URL`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_PRIVATE_BUCKET`, `S3_PUBLIC_BUCKET`, TURN/WebRTC переменные.

## Flutter

```powershell
cd mobile_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Для production укажи реальный `API_BASE_URL`. Release-сборка Windows запускается через `build_flutter_release.bat`.

## Tests

```powershell
cd backend
python -m pytest tests/ -q
```

```powershell
cd mobile_app
flutter test
flutter analyze
```

## Docs

- [Architecture](docs/architecture.md)
- [Architecture Rules](docs/architecture-rules.md)
- [Contracts](docs/contracts.md)
- [Realtime](docs/realtime.md)
- [Media](docs/media.md)
- [Calls](docs/calls.md)
- [Testing](docs/testing.md)
