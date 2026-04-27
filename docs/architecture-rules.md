# Architecture Rules

## Общие правила

- Не хранить секреты, локальные `.env`, build-артефакты и служебный мусор в git.
- Каждый слой должен иметь явную ответственность.
- Если логика становится общей или критичной для поведения продукта, она выносится из экранов и роутеров в отдельный слой.
- Нейминг должен отражать роль файла: `controller`, `state`, `service`, `repository`, `policy`, `use_case`.

## Backend

### Слои

- `api/` принимает запрос, валидирует базовый input, вызывает use case, возвращает response.
- `application/` orchestrates сценарий и координирует зависимости.
- `domain/` содержит бизнес-правила и политики доступа.
- `repositories/` отвечает за получение и сохранение данных.
- `infrastructure/` реализует внешние интеграции.
- `core/` хранит только действительно общие runtime-инструменты.

### Что запрещено

- Роутеры не содержат бизнес-логику.
- `domain` не знает про FastAPI, HTTP и transport details.
- `repositories` не формируют HTTP responses.
- `application` не должен разрастаться в смесь ORM-запросов, response-assembling и domain rules без явных границ.
- Нельзя держать два конкурирующих источника истины для одного и того же сервиса без явной причины.
- В Flutter message API временно канонизирован в `features/chats/data/services/messages_service.dart`; `features/messages/data/services/messages_service.dart` является compatibility export до полного переноса в `features/messages`.

## Mobile

### Слои

- `presentation/` — только UI и реакции на state.
- `controllers` или `application` — orchestration, lifecycle, subscriptions, reconnect, polling.
- `domain/` — правила, вычисления, политики, нормализация событий.
- `data/` — transport, storage, sockets, DTO/mappers.
- `core/` — только межмодульные общие инструменты.

### Что запрещено

- Screen не должен напрямую координировать множество сервисов низкого уровня.
- WebSocket event parsing не должен жить внутри больших UI-виджетов.
- Polling, reconnect, presence heartbeat и similar orchestration не должны быть размазаны по `setState`.
- `domain` не импортирует `presentation`.
- Reusable widgets не зависят от service layer.

## Размер и декомпозиция

- Большие экраны режутся на `screen + controller/state + widgets`.
- `part` допустим только как промежуточный шаг, а не как финальная архитектура.
- Если файл становится слишком большим и смешивает UI, state, transport и business rules, его нужно декомпозировать.

## Контракты

- REST и WebSocket payloads должны иметь единый канонический контракт.
- Маппинг из transport model в domain-friendly model выполняется централизованно.
- Ошибки маппятся последовательно: transport -> domain-friendly -> user-friendly.

## Тестируемость

- Критичная логика должна быть вынесена из UI/роутеров так, чтобы тестировалась отдельно.
- Приоритет тестов: domain rules, controllers/use cases, mappers/formatters, затем интеграция.

## Документация

- Любой новый архитектурный паттерн должен либо следовать этим правилам, либо сопровождаться обновлением правил.
- Для крупных feature-модулей приветствуются явные entry points вроде `features/chats/chats.dart`.
