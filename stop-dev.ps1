[CmdletBinding()]
param(
    [switch]$KeepDocker
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$ComposeFile = Join-Path $Root 'docker-compose.dev.yml'

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "    [OK] $Message" -ForegroundColor Green
}

function Stop-ProjectProcess {
    param(
        [int]$Port,
        [string]$Label,
        [scriptblock]$Predicate
    )

    $connection = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $connection) {
        Write-Ok "$Label is not running"
        return
    }

    $processId = $connection.OwningProcess
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$processId" -ErrorAction SilentlyContinue
    if (-not $process) {
        Write-Ok "$Label is not running"
        return
    }

    if (-not (& $Predicate $process)) {
        Write-Host "    [SKIP] Port $Port belongs to another process: $($process.Name) PID $processId" -ForegroundColor Yellow
        return
    }

    Stop-Process -Id $processId -Force
    $deadline = (Get-Date).AddSeconds(15)
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)) {
            Write-Ok "$Label stopped"
            return
        }
        Start-Sleep -Milliseconds 300
    }
    throw "$Label did not stop in time."
}

Write-Host 'Zeng Blog development one-click stopper' -ForegroundColor Yellow
Write-Host "Project root: $Root"

Write-Step 'Stopping Vue frontend'
Stop-ProjectProcess -Port 80 -Label 'Frontend' -Predicate {
    param($process)
    $process.Name -eq 'node.exe' -and $process.CommandLine -match 'my-blog.*web.*vite'
}

Write-Step 'Stopping Go backend'
Stop-ProjectProcess -Port 8080 -Label 'Backend' -Predicate {
    param($process)
    $process.Name -eq 'server.exe' -and (
        $process.CommandLine -match 'go-build' -or
        $process.ExecutablePath -match 'go-build'
    )
}

if (-not $KeepDocker) {
    Write-Step 'Stopping MySQL / Redis / Elasticsearch'
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        & docker info --format '{{.ServerVersion}}' *> $null
        if ($LASTEXITCODE -eq 0) {
            & docker compose -f $ComposeFile stop
            if ($LASTEXITCODE -ne 0) {
                throw 'docker compose stop failed.'
            }
            Write-Ok 'Docker services stopped'
            Write-Host '    Docker Desktop remains running.' -ForegroundColor DarkGray
        } else {
            Write-Ok 'Docker daemon is not running; skipped'
        }
    } else {
        Write-Ok 'docker command not found; skipped'
    }
} else {
    Write-Step 'Keeping MySQL / Redis / Elasticsearch running'
    Write-Ok 'Docker services were not stopped'
}

Write-Step 'Current status'
$frontend = Get-NetTCPConnection -State Listen -LocalPort 80 -ErrorAction SilentlyContinue
$backend = Get-NetTCPConnection -State Listen -LocalPort 8080 -ErrorAction SilentlyContinue
Write-Host ("  Frontend : " + $(if ($frontend) { 'running' } else { 'stopped' }))
Write-Host ("  Backend  : " + $(if ($backend) { 'running' } else { 'stopped' }))
Write-Host ''
Write-Host 'Stop completed.' -ForegroundColor Green
