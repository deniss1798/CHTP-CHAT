# Тестирование

## Backend

```bash
cd backend
python -m pytest tests/ -q
```

- Пример unit-теста без БД: `tests/test_message_projection.py` (нормализация `message_type`).
- Интеграционные тесты с БД можно добавить с отдельным `DATABASE_URL` и фикстурами в `tests/conftest.py` (по мере необходимости).

## Mobile (Flutter)

```bash
cd mobile_app
dart test
dart analyze
```

Виджетные и интеграционные тесты — в `mobile_app/test/` (расширять по фичам).
