# Deployment

## Backend

Production backend должен запускаться после применения миграций:

```powershell
cd backend
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Рекомендуемый production stack:

- PostgreSQL;
- reverse proxy с HTTPS;
- S3-compatible storage для приватных медиа;
- SMTP provider;
- Firebase credentials для push;
- coturn для WebRTC TURN.

## Flutter

Для production обязательно передать реальный API endpoint:

```powershell
cd mobile_app
flutter build windows --release --dart-define=API_BASE_URL=https://example.com/api
```

Для Android используется тот же `API_BASE_URL`, плюс platform-specific Firebase конфигурация.

## Runtime Checks

Перед выкладкой:

```powershell
cd backend
python -m pytest tests/ -q
python -m alembic heads
```

```powershell
cd mobile_app
flutter analyze
flutter test
```

На GitHub те же базовые проверки запускает `.github/workflows/ci.yml`: backend lint/tests, Flutter analyze/tests и security scan.

## Operational Notes

- Не деплоить `.env`, service account JSON и локальные ключи в git.
- Проверить CORS origins под реальный домен.
- Проверить, что release build не включает API logger.
- Проверить доступность `/webrtc/ice-config` и TURN relay для звонков из внешней сети.
- После schema changes применять миграции до запуска новой версии backend.
