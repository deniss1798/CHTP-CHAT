# Архитектура Messenger

## Слои backend (`backend/app/`)

| Слой | Назначение | Каталоги |
|------|------------|----------|
| API | HTTP-вход, привязка зависимостей, тонкие роутеры | `api/*_router.py`, `api/routers/messages/` (текст / медиа / выборки) |
| Application | Сценарии (orchestration), use cases | `application/chats/`, `application/messages/`, `application/auth/`, `application/media/`, `application/realtime/` |
| Domain | Политики доступа, правила без ORM-логики | `domain/policies/` |
| Repositories | Чтение/списки идентификаторов из БД (тонкий слой) | `repositories/` |
| Infrastructure | S3, перекодирование видео, TURN | `infrastructure/storage/`, `infrastructure/media/`, `infrastructure/turn/` |
| Core | Конфиг, безопасность, DI-хелперы | `core/` |

Роутеры вызывают функции application и domain-policies, не дублируют бизнес-правила.

## Слои mobile (`mobile_app/lib/features/<feature>/`)

- **presentation** — экраны и виджеты.
- **data** — REST/WebSocket/локальное хранилище.
- **domain** — чистые правила и контракты (расширяется по мере рефакторинга).

## Связанные документы

- [data-model.md](data-model.md)
- [realtime.md](realtime.md)
- [media.md](media.md)
- [calls.md](calls.md)
- [testing.md](testing.md)
