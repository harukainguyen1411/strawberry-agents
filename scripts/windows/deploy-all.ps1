# deploy-all.ps1
# Triggered by deploy-webhook after a push to main.
# 1. git pull --ff-only origin main (once, at repo root)
# 2. Read scripts/windows/deploy-services.json
# 3. Call deploy-service.ps1 for each entry sequentially
#
# Usage (run by Node.js as a detached child — not meant for direct invocation):
#   powershell -ExecutionPolicy Bypass -File scripts\windows\deploy-all.ps1

param(
    [string]$RepoRoot = (git rev-parse --show-toplevel)
)

$ErrorActionPreference = "Stop"
$ConfigFile  = Join-Path $RepoRoot "scripts\windows\deploy-services.json"
$DeployScript = Join-Path $RepoRoot "scripts\windows\deploy-service.ps1"

function Write-Log {
    param([string]$Msg)
    $ts = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Write-Host "[$ts] [deploy-all] $Msg"
}

Write-Log "=== Deploy started ==="

# ---------------------------------------------------------------------------
# 1. git pull
# ---------------------------------------------------------------------------
Write-Log "Running: git pull --ff-only origin main"
Push-Location $RepoRoot
try {
    git pull --ff-only origin main
    if ($LASTEXITCODE -ne 0) {
        Write-Log "ERROR: git pull failed (exit $LASTEXITCODE). Aborting deploy."
        exit 1
    }
} catch {
    Write-Log "ERROR: git pull threw an exception: $_"
    exit 1
} finally {
    Pop-Location
}
Write-Log "git pull succeeded."

# ---------------------------------------------------------------------------
# 2. Read service config
# ---------------------------------------------------------------------------
if (-not (Test-Path $ConfigFile)) {
    Write-Log "ERROR: Config file not found: $ConfigFile"
    exit 1
}

$Services = Get-Content $ConfigFile -Raw | ConvertFrom-Json
Write-Log "Services to deploy: $($Services.Count)"

# ---------------------------------------------------------------------------
# 3. Deploy each service sequentially
# ---------------------------------------------------------------------------
$AnyFailure = $false

foreach ($Svc in $Services) {
    $Name   = $Svc.name
    $AppDir = Join-Path $RepoRoot $Svc.appDir

    Write-Log "Deploying service: $Name (appDir: $AppDir)"

    try {
        & powershell -ExecutionPolicy Bypass -File $DeployScript `
            -ServiceName $Name `
            -AppDir $AppDir

        if ($LASTEXITCODE -ne 0) {
            Write-Log "ERROR: deploy-service.ps1 exited $LASTEXITCODE for $Name"
            $AnyFailure = $true
        } else {
            Write-Log "OK: $Name deployed successfully."
        }
    } catch {
        Write-Log "ERROR: Exception deploying ${Name}: $_"
        $AnyFailure = $true
    }
}

if ($AnyFailure) {
    Write-Log "=== Deploy finished WITH ERRORS ==="
    exit 1
} else {
    Write-Log "=== Deploy finished OK ==="
    exit 0
}
