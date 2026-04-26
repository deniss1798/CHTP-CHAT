# Медиа

## Константы и лимиты

Единый источник: `backend/app/application/media/constants.py` — MIME для изображений, видео, документов, максимальные размеры, множество типов сообщений с приватным медиа (`PRIVATE_MEDIA_MESSAGE_TYPES`), лимит аватара `MAX_AVATAR_SIZE`.

Текущие лимиты:

- аватар: 5 MB;
- изображение: 15 MB;
- голосовое: 20 MB;
- документ: 100 MB;
- видео / видеокружок: 100 MB.

## Хранение

- Реализация: `backend/app/infrastructure/storage/s3_storage.py` (загрузка в приватный bucket, presigned URL). Перекодирование видео: `infrastructure/media/video_transcode.py`.
- Построение ответов API с подменой URL: `application/messages/message_projection.py`.

## Жизненный цикл

1. Загрузка через эндпоинты `POST /messages/photo`, `/video`, `/video-note` или `/video_note`, `/voice`, `/document` или `/file`.
2. В БД сохраняются `media_key`, mime, размер. Для документов отображаемое имя хранится в `Message.text`.
3. При отдаче списка/детали сообщения подставляется временный URL, если S3 настроен (`is_private_s3_ready()`).
4. При пересылке медиа повторная загрузка не выполняется: новое сообщение ссылается на тот же `media_key`.

## Валидация

- Изображения проверяются по MIME и сигнатуре файла (`JPEG`, `PNG`, `WEBP`).
- Документы проверяются по allowlist расширений и соответствию `Content-Type`, кроме `application/octet-stream`, где доверяем расширению.
- Видео и голосовые сообщения ограничены allowlist MIME/расширений и лимитом размера.
