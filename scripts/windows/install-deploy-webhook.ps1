# install-deploy-webhook.ps1
# Installs deploy-webhook as a Windows service via NSSM.
# Run as Administrator:
#   powershell -ExecutionPolicy Bypass -File scripts\windows\install-deploy-webhook.ps1
#
# Idempotent — safe to re-run. Re-running stops, removes, and reinstalls the service.

param(
    [string]$NssmPath   = "nssm",
    [string]$NodePath   = (Get-Command node -ErrorAction Stop).Source,
    [string]$RepoRoot   = (git rev-parse --show-toplevel),
    [string]$Username   = "$($env:USERDOMAIN)\$($env:USERNAME)"
)

$ServiceName  = "deploy-webhook"
$DisplayName  = "Strawberry Deploy Webhook"
$Description  = "Receives GitHub push webhooks and triggers automatic deploy of all NSSM-managed services"

$AppDir       = Join-Path $RepoRoot "apps\deploy-webhook"
$MainJs       = Join-Path $AppDir "dist\index.js"
$LogDir       = Join-Path $AppDir "logs"

$SecretsDir   = Join-Path $env:USERPROFILE "deploy-webhook\secrets"
$EnvFile      = Join-Path $SecretsDir "webhook.env"

# ---------------------------------------------------------------------------
# 1. Build
# ---------------------------------------------------------------------------
Write-Host "Building deploy-webhook..."
Push-Location $AppDir
npm ci
npm run build
Pop-Location

# ---------------------------------------------------------------------------
# 2. Create directories
# ---------------------------------------------------------------------------
foreach ($dir in @($SecretsDir, $LogDir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-Host "Directory ensured: $dir"
}

# ---------------------------------------------------------------------------
# 3. Apply NTFS ACL — Full Control for Duong only, strip Users and Everyone
# ---------------------------------------------------------------------------
icacls $SecretsDir /inheritance:r | Out-Null
icacls $SecretsDir /remove "BUILTIN\Users"  2>$null | Out-Null
icacls $SecretsDir /remove "Everyone"       2>$null | Out-Null
icacls $SecretsDir /remove "NT AUTHORITY\Authenticated Users" 2>$null | Out-Null
icacls $SecretsDir /grant:r "${Username}:(OI)(CI)F" | Out-Null
Write-Host "NTFS ACL applied to $SecretsDir (Full Control: $Username only)"

# ---------------------------------------------------------------------------
# 4. Write env file template (only if not already present — protect real creds)
# ---------------------------------------------------------------------------
if (-not (Test-Path $EnvFile)) {
    $template = @"
# deploy-webhook environment variables
# Fill in DEPLOY_WEBHOOK_SECRET before starting the service.
# This file is protected by NTFS ACL — only $Username has access.

# Shared secret — must match the secret configured in GitHub repo Settings > Webhooks
DEPLOY_WEBHOOK_SECRET=REPLACE_WITH_REAL_SECRET

# Port to listen on (default 9000)
DEPLOY_WEBHOOK_PORT=9000

# Absolute path to the repo root — REQUIRED. NSSM sets AppDirectory to the app subdirectory,
# so process.cwd() is wrong without this. Set it to the root of the cloned repo.
DEPLOY_REPO_ROOT=C:\path\to\strawberry
"@
    Set-Content -Path $EnvFile -Value $template -Encoding UTF8
    Write-Host "Env file template written: $EnvFile"
    Write-Host "  -> Fill in DEPLOY_WEBHOOK_SECRET before starting the service."
} else {
    Write-Host "Env file already exists, skipping template write: $EnvFile"
}

# Re-apply ACL to env file
icacls $EnvFile /inheritance:r | Out-Null
icacls $EnvFile /remove "BUILTIN\Users"  2>$null | Out-Null
icacls $EnvFile /remove "Everyone"       2>$null | Out-Null
icacls $EnvFile /grant:r "${Username}:(R,W)" | Out-Null
Write-Host "NTFS ACL applied to $EnvFile (RW: $Username only)"

# ---------------------------------------------------------------------------
# 5. NSSM — uninstall existing, reinstall
# ---------------------------------------------------------------------------
& $NssmPath status $ServiceName 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Removing existing service $ServiceName..."
    & $NssmPath stop   $ServiceName confirm
    & $NssmPath remove $ServiceName confirm
}

Write-Host "Installing service $ServiceName..."
& $NssmPath install $ServiceName $NodePath $MainJs

& $NssmPath set $ServiceName AppDirectory       $AppDir
& $NssmPath set $ServiceName AppEnvironmentExtra "NODE_ENV=production" "DOTENV_CONFIG_PATH=$EnvFile"
& $NssmPath set $ServiceName AppStdout          (Join-Path $LogDir "stdout.log")
& $NssmPath set $ServiceName AppStderr          (Join-Path $LogDir "stderr.log")
& $NssmPath set $ServiceName AppRotateFiles     1
& $NssmPath set $ServiceName AppRotateBytes     10485760   # 10 MB
& $NssmPath set $ServiceName AppRestartDelay    5000       # 5 s delay before auto-restart
& $NssmPath set $ServiceName Start              SERVICE_AUTO_START
& $NssmPath set $ServiceName DisplayName        $DisplayName
& $NssmPath set $ServiceName Description        $Description
# ObjectName intentionally omitted — service runs as LocalSystem.
# If you need a specific user account, set ObjectName manually and supply the password:
#   nssm set deploy-webhook ObjectName DOMAIN\Username
#   nssm set deploy-webhook ObjectPassword yourpassword

# ---------------------------------------------------------------------------
# 6. Start
# ---------------------------------------------------------------------------
Write-Host "Starting service $ServiceName..."
& $NssmPath start $ServiceName

Write-Host ""
Write-Host "Done. Service status:"
& $NssmPath status $ServiceName
Write-Host ""
Write-Host "Secrets dir : $SecretsDir"
Write-Host "Env file    : $EnvFile"
Write-Host "Logs        : $LogDir"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Edit $EnvFile and set DEPLOY_WEBHOOK_SECRET."
Write-Host "  2. Expose port 9000 to GitHub - choose one option:"
Write-Host "       a. Port forward (router config) - simplest if your ISP gives a stable public IP."
Write-Host "       b. Cloudflare Tunnel (cloudflared) - free, no port forwarding."
Write-Host "          Install: winget install --id Cloudflare.cloudflared"
Write-Host "          Run: cloudflared tunnel --url http://localhost:9000"
Write-Host "          Register as NSSM service for persistence."
Write-Host "       c. ngrok - free tier works but URL changes on restart."
Write-Host "          ngrok http 9000"
Write-Host "  3. In GitHub: Settings > Webhooks > Add webhook"
Write-Host "       Payload URL : http://<your-public-host>:9000/webhook"
Write-Host "       Content type: application/json"
Write-Host "       Secret      : same value as DEPLOY_WEBHOOK_SECRET in $EnvFile"
Write-Host "       Events      : Just the push event"
Write-Host "  4. Run: nssm restart $ServiceName"
Write-Host "  5. Verify: curl http://localhost:9000/health"
