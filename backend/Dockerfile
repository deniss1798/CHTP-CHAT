FROM python:3.14-slim AS builder
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg gcc && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt pyinstaller
COPY . .
RUN ls -la /app && ls -la /app/app || echo "no /app/app folder"
RUN pyinstaller --onefile \
    --name app \
    --hidden-import uvicorn \
    --hidden-import uvicorn.loops \
    --hidden-import uvicorn.loops.auto \
    --hidden-import uvicorn.protocols \
    --hidden-import uvicorn.protocols.http \
    --hidden-import uvicorn.protocols.http.auto \
    app/main.py   # предполагаем, что main.py в корне

FROM alpine:3.23.4
RUN apk add --no-cache ffmpeg libstdc++
WORKDIR /app
COPY --from=builder /app/dist/app .
RUN chmod +x ./app && adduser -D -u 1000 appuser && chown appuser:appuser /app
USER appuser
EXPOSE 8000
CMD ["./app"]
