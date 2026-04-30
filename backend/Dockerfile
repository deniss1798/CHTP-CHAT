FROM python:3.14-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    gcc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .

# Устанавливаем зависимости приложения и PyInstaller
RUN pip install --no-cache-dir -r requirements.txt pyinstaller

COPY . .

RUN pyinstaller --onefile \
    --name app \
    --add-data "app/templates:templates" \
    --hidden-import uvicorn \
    --hidden-import uvicorn.loops \
    --hidden-import uvicorn.loops.auto \
    --hidden-import uvicorn.protocols \
    --hidden-import uvicorn.protocols.http \
    --hidden-import uvicorn.protocols.http.auto \
    app/main.py   # замените на ваш файл, содержащий объект app

FROM alpine:latest

RUN apk add --no-cache ffmpeg libstdc++

WORKDIR /app

# Копируем собранный бинарник из этапа builder
COPY --from=builder /app/dist/app .

RUN chmod +x ./app

RUN adduser -D -u 1000 appuser && chown appuser:appuser /app
USER appuser

EXPOSE 8000

# Запускаем бинарник. Uvicorn уже внутри него.
CMD ["./app"]
