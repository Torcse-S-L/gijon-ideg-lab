# =============================================================================
# bootstrap_lab.ps1
# Inicialización del entorno IDEG Gijón en Windows (PowerShell)
# =============================================================================
param(
    [switch]$SeedCache
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectDir = Split-Path -Parent $ScriptDir

function Log    { param($msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" }
function LogOk  { param($msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [OK] $msg" -ForegroundColor Green }
function LogErr { param($msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [ERR] $msg" -ForegroundColor Red; exit 1 }

# ── Verificar dependencias ────────────────────────────────────────────────────
foreach ($cmd in @("docker", "curl")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        LogErr "$cmd no encontrado en PATH."
    }
}
try { docker compose version | Out-Null } catch { LogErr "docker compose v2 requerido." }

# ── Verificar .env ────────────────────────────────────────────────────────────
$envFile = Join-Path $ProjectDir ".env"
if (-not (Test-Path $envFile)) {
    Log "Copiando .env.example a .env..."
    Copy-Item (Join-Path $ProjectDir ".env.example") $envFile
    LogErr "Edita $envFile antes de continuar."
}
# Cargar variables del .env
Get-Content $envFile | Where-Object { $_ -match "^[^#].*=.*" } | ForEach-Object {
    $parts = $_ -split "=", 2
    [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
}

# ── Levantar stack ────────────────────────────────────────────────────────────
Log "Levantando PostgreSQL..."
Set-Location $ProjectDir
docker compose up -d postgres

Log "Esperando a PostgreSQL..."
$retries = 30
do {
    Start-Sleep 3
    $retries--
    $result = docker compose exec -T postgres pg_isready -U $env:POSTGRES_USER -d $env:POSTGRES_DB 2>&1
} while ($result -notmatch "accepting connections" -and $retries -gt 0)
if ($retries -le 0) { LogErr "PostgreSQL no disponible." }
LogOk "PostgreSQL listo."

Log "Levantando stack completo..."
docker compose up -d
LogOk "Stack levantado."

# ── Resumen ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  IDEG Gijón Lab — Stack levantado" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Visor IDEG:  http://localhost:$($env:MAPSTORE_PORT ?? 80)/ideg"
Write-Host "  GeoServer:   http://localhost:$($env:GEOSERVER_PORT ?? 8080)/geoserver"
Write-Host "  GeoNetwork:  http://localhost:$($env:GEONETWORK_PORT ?? 8081)/geonetwork"
Write-Host "  Grafana:     http://localhost:$($env:GRAFANA_PORT ?? 3000)"
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Tests: .\tests\test_ideg_e2e.ps1"
Write-Host ""
