# Тестирование

## Backend

```bash
cd backend
python -m pytest tests/ -q
```

- Пример unit-теста без БД: `tests/test_message_projection.py` (нормализация `message_type`).
- Интеграционные тесты с SQLite in-memory используют `tests/conftest.py`.
- Priority 3 покрыт тестами ролей групп, `call_event` сообщений, `/devices` управления токенами и отключения push через notification settings.
- Медиа-этап покрыт тестами лимитов, document validation и проверки сигнатуры изображений.

## Mobile (Flutter)

```bash
cd mobile_app
dart test
dart analyze
```

Виджетные и интеграционные тесты — в `mobile_app/test/` (расширять по фичам). Для Priority 3 добавлены unit-тесты правил превью чатов и строк истории звонков. Для медиа добавлены тесты форматтеров документа и `file` alias.
