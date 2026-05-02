# Deployment

## Каноничный production: схема

Пользователи **не** ходят в контейнер на порт 8000 с интернета. Снаружи открыты только **80/443 (nginx)**, бэкенд слушает **только с localhost**:

```text
Интернет → HTTPS (nginx :443) → http://127.0.0.1:8000 (Docker, uvicorn)
```

- **API и WebSocket** у клиента в коде: один базовый URL, например `https://api.ваш-домен.ru` **или** `https://ваш-домен.ru/api` (как настроен nginx; в проекте FastAPI дублирует маршруты с префиксом `/api`).
- **Релизные** сборки Flutter: `API_BASE_URL` задаётся **при сборке** (`--dart-define`), значения в CI/секретах, **не** в репозитории.
- Локальный **`api_base_url.txt`** рядом с exe (см. `api_config_io.dart`) — **опционально** (внутренние сборки, отладка); для пользователей в продукте ориентир — **сборка с правильным `dart-define`**.

---

## Nginx: reverse proxy, HTTPS, WebSocket (пошагово)

Ниже — **один** рабочий вариант: домен `example.com`, бэкенд в Docker на `127.0.0.1:8000`, клиент использует `https://example.com/api` (и запросы идут на `https://example.com/api/...`).

### 1) DNS

Запись **A** для `example.com` (и при необходимости `api.example.com`) → публичный IP сервера.

### 2) Docker слушать только localhost (рекомендуется)

Чтобы порт 8000 **не** торчал в интернет (даже если забыли ufw):

```bash
sudo docker stop py-backend
sudo docker rm py-backend
sudo docker run -d --name py-backend -p 127.0.0.1:8000:8000 --env-file /var/www/CHTP-CHAT/backend/.env py-backend:latest
sudo docker exec py-backend alembic upgrade head
```

Проверка только с сервера:

```bash
curl -sS http://127.0.0.1:8000/health
```

### 3) Создать конфиг nginx

```bash
sudo nano /etc/nginx/sites-available/chtp-api.conf
```

Минимальный пример (замените `example.com` и пути; для WebSocket — блок `map` + заголовки):

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    listen [::]:80;
    server_name example.com;

    # после certbot сюда добавятся listen 443 ssl; и сертификаты — или отдельный server для HTTPS
    # сейчас: редирект на HTTPS (раскомментируйте после появления ssl)
    # return 301 https://$host$request_uri;

    # Размер тела (медиа) — подстройте
    client_max_body_size 100M;

    # Всё API + WebSocket (пути /api/ws/...)
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_read_timeout 86400;
    }

    # Опционально: health без /api (у приложения есть GET /health в корне)
    location = /health {
        proxy_pass http://127.0.0.1:8000/health;
        proxy_set_header Host $host;
    }

    # Статика media из FastAPI, если забираете через тот же хост
    location /media/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
    }
}
```

Активировать:

```bash
sudo ln -sf /etc/nginx/sites-available/chtp-api.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 4) TLS (Let’s Encrypt)

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d example.com
```

Certbot обычно **сам** добавит `listen 443 ssl` и редирект с 80. После этого проверь:

```bash
curl -sS https://example.com/health
curl -sS https://example.com/api/ready
```

### 5) CORS в backend

В `backend/.env` на сервере задайте реальные origin клиента (для **Flutter Web**; мобильные/десктоп часто не требуют, но лишним не бывает), например:

```env
CORS_ORIGINS=https://example.com,https://www.example.com
```

Перезапуск контейнера после смены env.

### 6) Фаервол

Снаружи: **только 80, 443, 22(или ваш SSH порт)**. Порт **8000 наружу не открывать**.

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22201/tcp   # если SSH на нестандартном, как у вас
sudo ufw reload
```

### 7) Клиент: релизная сборка (правильно для пользователей)

```powershell
cd mobile_app
flutter build windows --release --dart-define=API_BASE_URL=https://example.com/api
```

Подставьте **тот же** базовый URL, который реально открывается в браузере (схема `https`, путь с `/api` как у вас в nginx + FastAPI).  
Проверка до сборки с ПК (должны быть 200 и JSON):

```powershell
curl -sS "https://example.com/api/ready"
curl -sS "https://example.com/health"
```

У приложения в корне есть `GET /health` и `GET /api/ready` (см. `main.py`); отдельного `GET /api/health` может не быть.

---

## Backend

Production backend должен запускаться после применения миграций:

```powershell
cd backend
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Рекомендуемый production stack:

- PostgreSQL;
- reverse proxy с HTTPS;
- S3-compatible storage для приватных медиа;
- SMTP provider;
- Firebase credentials для push;
- coturn для WebRTC TURN.

## Flutter (мобильные тот же API_BASE_URL)

- Windows: см. п. 7 в разделе **«Nginx: reverse proxy…»**.
- Android / iOS: тот же `--dart-define=API_BASE_URL=...` в CI, плюс Firebase и подписи магазинов.

## Runtime Checks

Перед выкладкой:

```powershell
cd backend
python -m pytest tests/ -q
python -m alembic heads
```

```powershell
cd mobile_app
flutter analyze
flutter test
```

На GitHub те же базовые проверки запускает `.github/workflows/ci.yml`: backend lint/tests, Flutter analyze/tests и security scan.

## Operational Notes

- Не деплоить `.env`, service account JSON и локальные ключи в git.
- Проверить CORS origins под реальный домен.
- Проверить, что release build не включает API logger.
- Проверить доступность `/webrtc/ice-config` и TURN relay для звонков из внешней сети.
- После schema changes применять миграции до запуска новой версии backend.
