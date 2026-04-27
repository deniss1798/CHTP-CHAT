# Тестирование

## Backend

```bash
cd backend
python -m pytest tests/ -q
```

- Пример unit-теста без БД: `tests/test_message_projection.py` (нормализация `message_type`).
- Интеграционные тесты с SQLite in-memory используют `tests/conftest.py`.
- API-тесты через FastAPI `TestClient` используют тот же in-memory SQLite и dependency override для `get_db`, без реального email/S3/Firebase.
- Priority 3 покрыт тестами ролей групп, `call_event` сообщений, `/devices` управления токенами и отключения push через notification settings.
- Медиа-этап покрыт тестами лимитов, document validation и проверки сигнатуры изображений.
- Security roadmap: добавлены smoke-тесты auth/users/chats/messages endpoint и проверки rate-limit для login/message send.
- Performance roadmap: добавлены query-count тесты для списка чатов и сообщений.
- Calls roadmap: добавлены тесты call state machine и backend contract таблицы `calls`.
- Observability (этап 12): `X-Request-ID` на HTTP-ответах, `/ready` / `/api/ready` (readiness, 503 при падении чека БД), тесты `test_observability_stage12.py`. CI: `flutter analyze --no-fatal-infos` (без валидного exit при одних `info` от линтера).

## Pre-commit

Перед первым использованием:

```bash
pip install -r backend/requirements-dev.txt
pre-commit install
```

Локальная проверка всех hooks:

```bash
pre-commit run --all-files
```

Hooks запускают `ruff`, `black --check`, `pytest`, `dart format --set-exit-if-changed` и `flutter analyze`.

## CI

GitHub Actions workflow находится в `.github/workflows/ci.yml` и запускается на `pull_request`, а также на push в `main`/`master`.

Проверки:

- backend lint: `ruff`, `black --check`;
- backend tests: `pytest`;
- Flutter: `dart format`, `flutter analyze`, `flutter test`;
- security scan: `bandit`.

## Mobile (Flutter)

```bash
cd mobile_app
flutter test
flutter analyze
```

Виджетные и интеграционные тесты — в `mobile_app/test/` (расширять по фичам). Для Priority 3 добавлены unit-тесты правил превью чатов и строк истории звонков. Для медиа добавлены тесты форматтеров документа и `file` alias.
