# Security

## Authentication

- Пользователь получает JWT access token после регистрации или login.
- WebSocket подключается через короткоживущий `ws_token` из `POST /auth/ws-token`.
- Backend временно принимает обычный access token для WebSocket только для совместимости.

## Email Verification

- Email-коды генерируются через cryptographically secure random.
- Код хранится в БД в hashed виде, а не plaintext.
- Повторные попытки ограничены rate limit.

## Rate Limits

In-memory rate limiter применяется к:

- login;
- request/verify email code;
- отправке сообщений;
- media uploads;
- WebSocket connect.

Для production с несколькими backend-инстансами rate limits нужно вынести в общий storage, например Redis.

## Logs

- Backend устанавливает redaction filter для чувствительных полей.
- Flutter API logger включается только в debug.
- Нельзя логировать access token, password, verification code, private media keys.

## Media

- Private media хранится в S3-compatible bucket.
- Клиент получает presigned URL с коротким TTL.
- `media_key` не должен возвращаться как публичный контракт.
- Upload validation проверяет MIME, расширение, размер и сигнатуры изображений.

## HTTP Headers

Backend добавляет базовые security headers:

- `X-Content-Type-Options`;
- `X-Frame-Options`;
- `Referrer-Policy`;
- `Strict-Transport-Security` при HTTPS.

## Devices

- Push-токены можно отозвать по одному или все сразу.
- Notification settings позволяют отключить FCM-доставку для пользователя.
