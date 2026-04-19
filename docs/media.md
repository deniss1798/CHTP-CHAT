# Медиа

## Константы и лимиты

Единый источник: `backend/app/application/media/constants.py` — MIME для изображений, видео, документов, максимальные размеры, множество типов сообщений с приватным медиа (`PRIVATE_MEDIA_MESSAGE_TYPES`), лимит аватара `MAX_AVATAR_SIZE`.

## Хранение

- Реализация: `backend/app/infrastructure/storage/s3_storage.py` (загрузка в приватный bucket, presigned URL). Перекодирование видео: `infrastructure/media/video_transcode.py`.
- Построение ответов API с подменой URL: `application/messages/message_projection.py`.

## Жизненный цикл

1. Загрузка через эндпоинты `POST /messages/photo`, `/video`, `/video-note`, `/document`.
2. В БД сохраняются `media_key`, mime, размер.
3. При отдаче списка/детали сообщения подставляется временный URL, если S3 настроен (`is_private_s3_ready()`).
