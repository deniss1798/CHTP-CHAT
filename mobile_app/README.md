# mobile_app

Flutter-клиент Messanger.

## Поддерживаемые платформы

- Android
- Windows
- другие платформы Flutter по мере готовности

## Основные зависимости

- `dio`
- `firebase_core`
- `firebase_messaging`
- `flutter_webrtc`
- `image_picker`
- `file_picker`
- `desktop_drop`

## Запуск

```powershell
cd mobile_app
flutter pub get
flutter run
```

## Release build

Из корня репозитория:

```powershell
build_flutter_release.bat
```

Или вручную с `--dart-define` для TURN/WebRTC.

## Архитектура

- `features/*/presentation` — UI
- `features/*/data` — API, sockets, storage
- `features/*/domain` — правила и модели уровня предметной области
- `core/` — общие межмодульные инструменты

Цель архитектуры:

- не держать orchestration внутри экранов
- выносить state и controller отдельно от UI
- не смешивать websocket/polling/reconnect с виджетами
- держать reusable widgets независимыми от service layer

Контракты событий и API:

- [../docs/contracts.md](../docs/contracts.md)
- `lib/core/realtime/chat_ws_contract.dart`

## Качество

```powershell
cd mobile_app
flutter analyze
flutter test
```
