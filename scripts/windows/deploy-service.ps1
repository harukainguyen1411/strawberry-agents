# deploy-service.ps1
# Per-service build + NSSM restart.
# Called by deploy-all.ps1 for each service entry.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\windows\deploy-service.ps1 `
#       -ServiceName <nssm-service-name> `
#       -AppDir <absolute-path-to-app>

param(
    [Parameter(Mandatory)][string]$ServiceName,
    [Parameter(Mandatory)][string]$AppDir,
    [string]$NssmPath = "nssm"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Msg)
    $ts = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Write-Host "[$ts] [deploy-service:$ServiceName] $Msg"
}

# ---------------------------------------------------------------------------
# 1. npm run build
# ---------------------------------------------------------------------------
if (-not (Test-Path (Join-Path $AppDir "package.json"))) {
    Write-Log "ERROR: package.json not found in $AppDir"
    exit 1
}

Write-Log "Installing dependencies: npm ci in $AppDir"
Push-Location $AppDir
try {
    npm ci
    if ($LASTEXITCODE -ne 0) {
        Write-Log "ERROR: npm ci failed (exit $LASTEXITCODE). Skipping build and restart."
        exit 1
    }
} catch {
    Write-Log "ERROR: npm ci threw an exception: $_"
    exit 1
} finally {
    Pop-Location
}
Write-Log "Dependencies installed."

Write-Log "Building: npm run build in $AppDir"
Push-Location $AppDir
try {
    npm run build
    if ($LASTEXITCODE -ne 0) {
        Write-Log "ERROR: npm run build failed (exit $LASTEXITCODE). Skipping restart."
        exit 1
    }
} catch {
    Write-Log "ERROR: npm run build threw an exception: $_"
    exit 1
} finally {
    Pop-Location
}
Write-Log "Build succeeded."

# ---------------------------------------------------------------------------
# 2. nssm restart
# ---------------------------------------------------------------------------
Write-Log "Restarting NSSM service: $ServiceName"
try {
    & $NssmPath restart $ServiceName
    if ($LASTEXITCODE -ne 0) {
        Write-Log "ERROR: nssm restart exited $LASTEXITCODE for $ServiceName"
        exit 1
    }
} catch {
    Write-Log "ERROR: nssm restart threw an exception: $_"
    exit 1
}

Write-Log "Service $ServiceName restarted successfully."
exit 0
