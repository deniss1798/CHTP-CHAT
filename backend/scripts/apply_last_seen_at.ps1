# Применяет миграцию с last_seen_at (предпочтительно через Alembic).
# Запуск из корня репозитория или из backend:
#   cd backend
#   .\scripts\apply_last_seen_at.ps1

$ErrorActionPreference = "Stop"

$backendRoot = Split-Path $PSScriptRoot -Parent
Set-Location $backendRoot
Write-Host "Каталог: $backendRoot" -ForegroundColor Cyan

$alembic = Get-Command alembic -ErrorAction SilentlyContinue
if ($alembic) {
    Write-Host "Выполняю: alembic upgrade head" -ForegroundColor Green
    & alembic upgrade head
    exit $LASTEXITCODE
}

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command py -ErrorAction SilentlyContinue }
if ($py) {
    Write-Host "Выполняю: python -m alembic upgrade head" -ForegroundColor Green
    & $py.Source -m alembic upgrade head
    exit $LASTEXITCODE
}

Write-Host "Не найдены alembic и python. Примени вручную SQL:" -ForegroundColor Yellow
Write-Host "  scripts\sql\add_users_last_seen_at.sql" -ForegroundColor Yellow
exit 1
