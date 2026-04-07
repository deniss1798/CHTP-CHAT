# TCP check for DB (same layer as DBeaver before auth).
# cd backend
# .\scripts\diagnose_db_connection.ps1
# .\scripts\diagnose_db_connection.ps1 83.217.201.40 5432

param(
    [string]$DbHost,
    [int]$DbPort = 0
)

$ErrorActionPreference = "Stop"

function Parse-PostgresUrl {
    param([string]$Url)
    if ($Url -match '@([^:/]+):(\d+)/') {
        return @{ Host = $matches[1]; Port = [int]$matches[2] }
    }
    if ($Url -match '@([^:/]+)/') {
        return @{ Host = $matches[1]; Port = 5432 }
    }
    return $null
}

$envPath = Join-Path (Split-Path $PSScriptRoot -Parent) ".env"
if (-not $DbHost -and (Test-Path $envPath)) {
    $dbLine = Get-Content $envPath -Encoding UTF8 | Where-Object { $_ -match '^\s*DATABASE_URL\s*=' } | Select-Object -First 1
    if ($dbLine) {
        $raw = ($dbLine -replace '^\s*DATABASE_URL\s*=\s*', '').Trim().Trim('"').Trim("'")
        $parsed = Parse-PostgresUrl $raw
        if ($parsed) {
            $DbHost = $parsed.Host
            if ($DbPort -le 0) { $DbPort = $parsed.Port }
            Write-Host "From .env: host=$DbHost port=$DbPort" -ForegroundColor Cyan
        }
    }
}

if (-not $DbHost) {
    Write-Host "Usage: .\scripts\diagnose_db_connection.ps1 <host> [port]" -ForegroundColor Yellow
    Write-Host "Or set backend\.env DATABASE_URL=postgresql://...@host:port/..." -ForegroundColor Yellow
    exit 1
}

if ($DbPort -le 0) { $DbPort = 5432 }

Write-Host "Testing TCP ${DbHost}:$DbPort ..." -ForegroundColor Cyan
$t = Test-NetConnection -ComputerName $DbHost -Port $DbPort -WarningAction SilentlyContinue

if ($t.TcpTestSucceeded) {
    Write-Host "OK: port is open (network/firewall allows TCP)." -ForegroundColor Green
    Write-Host "If DBeaver still times out: check SSL mode, credentials, pg_hba.conf, driver." -ForegroundColor Gray
    exit 0
}

Write-Host "FAIL: TcpTestSucceeded = False (cannot reach host:port)." -ForegroundColor Red
Write-Host "Common: DB stopped, wrong IP/port, firewall/security group, Postgres listen_addresses=localhost only." -ForegroundColor Yellow
exit 2
