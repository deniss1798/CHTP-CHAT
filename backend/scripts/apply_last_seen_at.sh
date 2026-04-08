#!/usr/bin/env bash
# Применяет миграцию last_seen_at через Alembic.
# Запуск: из каталога backend
#   chmod +x scripts/apply_last_seen_at.sh
#   ./scripts/apply_last_seen_at.sh

set -euo pipefail
cd "$(dirname "$0")/.."
echo "Каталог: $(pwd)"
exec alembic upgrade head
