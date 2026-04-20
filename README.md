# Messanger

Кроссплатформенный мессенджер с Flutter-клиентом и FastAPI backend.

## Состав проекта

- `backend/` — API, WebSocket realtime, media, auth, calls signaling, PostgreSQL, Docker.
- `mobile_app/` — Flutter-клиент для Android, Windows и других платформ Flutter.
- `docs/` — архитектура, realtime, media, calls, data model, testing rules.

## Технологии

- Backend: `FastAPI`, `SQLAlchemy`, `Alembic`, `PostgreSQL`, `WebSocket`
- Mobile: `Flutter`, `Dio`, `Firebase Messaging`, `flutter_webrtc`
- Infra: `Docker`, `S3-compatible storage`, `TURN / WebRTC`

## Быстрый старт

### Backend

1. Перейти в `backend/`
2. Создать локальный `.env` на основе `.env.example`
3. Поднять PostgreSQL
4. Установить зависимости
5. Применить миграции
6. Запустить приложение

Пример:

```powershell
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload
```

### Mobile

1. Перейти в `mobile_app/`
2. Установить Flutter-зависимости
3. Передать нужные `--dart-define` для TURN/WebRTC
4. Запустить или собрать нужную платформу

Пример:

```powershell
cd mobile_app
flutter pub get
flutter run
```

Для release-сборок есть батник:

```powershell
build_flutter_release.bat
```

## Архитектура

### Backend

- `api/` — только транспортный слой и тонкие роутеры
- `application/` — use cases и orchestration
- `domain/` — политики и бизнес-правила
- `repositories/` — доступ к данным
- `infrastructure/` — S3, TURN, media processing
- `core/` — config, security, DI, shared runtime helpers

### Mobile

- `presentation/` — экраны и UI-виджеты
- `data/` — API, sockets, storage
- `domain/` — правила, сущности, вычисления
- `controllers/state` — orchestration между UI и data/domain

Подробности:

- [docs/architecture.md](C:/Users/User/Desktop/Messanger/docs/architecture.md)
- [docs/architecture-rules.md](C:/Users/User/Desktop/Messanger/docs/architecture-rules.md)
- [docs/contracts.md](C:/Users/User/Desktop/Messanger/docs/contracts.md)
- [docs/realtime.md](C:/Users/User/Desktop/Messanger/docs/realtime.md)
- [docs/testing.md](C:/Users/User/Desktop/Messanger/docs/testing.md)

## Правила репозитория

- Реальные секреты не хранятся в git
- В репо лежат только примеры конфигов, например `.env.example`
- Build-артефакты, `__pycache__`, логи и локальные IDE-файлы в git не коммитятся
- Архитектурные правила для слоёв зафиксированы в `docs/architecture-rules.md`

## Проверка качества

Backend:

```powershell
cd backend
pytest
```

Mobile:

```powershell
cd mobile_app
flutter analyze
flutter test
```
