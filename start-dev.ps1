[CmdletBinding()]
param(
    [int]$FrontendPort = 80,
    [switch]$OpenBrowser,
    [switch]$SkipFrontend,
    [switch]$SkipBackend
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$ComposeFile = Join-Path $Root 'docker-compose.dev.yml'
$ServerDir = Join-Path $Root 'server'
$WebDir = Join-Path $Root 'web'

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "    [OK] $Message" -ForegroundColor Green
}

function Test-TcpPort([int]$Port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync('127.0.0.1', $Port)
        if ($task.Wait(800) -and $client.Connected) { return $true }
        return $false
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

function Wait-TcpPort([int]$Port, [int]$TimeoutSeconds) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-TcpPort $Port) { return $true }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Test-DockerDaemon {
    & docker info --format '{{.ServerVersion}}' *> $null
    return ($LASTEXITCODE -eq 0)
}

function Start-DockerDesktopIfNeeded {
    if (Test-DockerDaemon) { return }

    Write-Step 'Docker daemon is not running. Trying to start Docker Desktop'
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\Docker Desktop.exe'),
        (Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe')
    )
    $exe = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $exe) {
        throw 'Docker Desktop was not found. Start Docker Desktop manually and retry.'
    }

    Start-Process -FilePath $exe -WindowStyle Hidden
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        if (Test-DockerDaemon) {
            Write-Ok 'Docker daemon is ready'
            return
        }
    }
    throw 'Docker Desktop startup timed out. Open Docker Desktop and check its status.'
}

Write-Host 'Zeng Blog development one-click launcher' -ForegroundColor Yellow
Write-Host "Project root: $Root"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'docker command not found. Install Docker Desktop first.'
}
if (-not (Test-Path -LiteralPath (Join-Path $ServerDir 'config.yaml'))) {
    throw 'Missing server/config.yaml. Create the backend config first.'
}

Start-DockerDesktopIfNeeded

Write-Step 'Starting MySQL / Redis / Elasticsearch'
& docker compose -f $ComposeFile up -d
if ($LASTEXITCODE -ne 0) { throw 'docker compose up failed.' }

Write-Step 'Waiting for infrastructure health checks'
$containers = @('my-blog-mysql-dev', 'my-blog-redis-dev', 'my-blog-elasticsearch-dev')
$deadline = (Get-Date).AddSeconds(120)
while ($true) {
    $states = foreach ($name in $containers) {
        $state = (& docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $name 2>$null)
        [pscustomobject]@{ Name = $name; State = ($state | Select-Object -First 1) }
    }
    $unhealthy = @($states | Where-Object { $_.State -ne 'healthy' })
    if ($unhealthy.Count -eq 0) {
        $states | ForEach-Object { Write-Ok "$($_.Name): $($_.State)" }
        break
    }
    if ((Get-Date) -ge $deadline) {
        $states | Format-Table -AutoSize | Out-String | Write-Host
        throw 'Infrastructure health check timed out.'
    }
    Start-Sleep -Seconds 3
}

if (-not $SkipBackend) {
    Write-Step 'Checking Go backend'
    if (Test-TcpPort 8080) {
        Write-Ok 'Backend is already running on port 8080'
    } else {
        $go = (Get-Command go -ErrorAction Stop).Source
        $outLog = Join-Path $ServerDir 'run.out.log'
        $errLog = Join-Path $ServerDir 'run.err.log'
        Start-Process -FilePath $go -ArgumentList @('run', '.') -WorkingDirectory $ServerDir -RedirectStandardOutput $outLog -RedirectStandardError $errLog -WindowStyle Hidden
        if (-not (Wait-TcpPort 8080 120)) {
            throw "Backend startup timed out. Check $outLog and $errLog."
        }
        Write-Ok 'Backend started: http://127.0.0.1:8080'
    }
}

if (-not $SkipFrontend) {
    Write-Step 'Checking Vue frontend'
    if (Test-TcpPort $FrontendPort) {
        Write-Ok "Frontend is already running on port $FrontendPort"
    } else {
        if (-not (Test-Path -LiteralPath (Join-Path $WebDir 'node_modules'))) {
            Write-Step 'First run: installing frontend dependencies'
            & npm.cmd --prefix $WebDir ci
            if ($LASTEXITCODE -ne 0) { throw 'npm ci failed.' }
        }
        $npm = (Get-Command npm.cmd -ErrorAction Stop).Source
        $outLog = Join-Path $WebDir 'dev.out.log'
        $errLog = Join-Path $WebDir 'dev.err.log'
        Start-Process -FilePath $npm -ArgumentList @('run', 'dev', '--', '--host', '0.0.0.0', '--port', "$FrontendPort") -WorkingDirectory $WebDir -RedirectStandardOutput $outLog -RedirectStandardError $errLog -WindowStyle Hidden
        if (-not (Wait-TcpPort $FrontendPort 90)) {
            throw "Frontend startup timed out. Check $outLog and $errLog."
        }
        Write-Ok "Frontend started: http://127.0.0.1:$FrontendPort"
    }
}

Write-Step 'Current endpoints'
Write-Host "  Frontend: http://127.0.0.1:$FrontendPort/" -ForegroundColor White
Write-Host '  Backend:  http://127.0.0.1:8080' -ForegroundColor White
Write-Host '  API:      http://127.0.0.1:8080/api/website/info' -ForegroundColor White
Write-Host '  Docker:   mysql / redis / elasticsearch' -ForegroundColor White
Write-Host ''
Write-Host 'Startup completed.' -ForegroundColor Green

if ($OpenBrowser) {
    Start-Process "http://127.0.0.1:$FrontendPort/"
}
