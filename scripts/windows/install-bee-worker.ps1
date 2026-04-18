# install-bee-worker.ps1
# Installs bee-worker as a Windows service via NSSM.
# Run as Administrator:
#   powershell -ExecutionPolicy Bypass -File scripts\windows\install-bee-worker.ps1
#
# Idempotent — safe to re-run. Re-running stops, removes, and reinstalls the service.

param(
    [string]$NssmPath   = "nssm",
    [string]$NodePath   = (Get-Command node -ErrorAction Stop).Source,
    [string]$RepoRoot   = (git rev-parse --show-toplevel),
    [string]$Username   = "$($env:USERDOMAIN)\$($env:USERNAME)"
)

$ServiceName  = "bee-worker"
$DisplayName  = "Strawberry Bee Worker"
$Description  = "Polls Firestore for queued Bee jobs and invokes Claude Code to produce OOXML-commented docx files"

$WorkerDir    = Join-Path $RepoRoot "apps\bee-worker"
$MainJs       = Join-Path $WorkerDir "dist\index.js"
$LogDir       = Join-Path $WorkerDir "logs"

$SecretsDir   = Join-Path $env:USERPROFILE "bee\secrets"
$AuditDir     = Join-Path $env:USERPROFILE "bee-audit"
$EnvFile      = Join-Path $SecretsDir "bee-worker.env"

# ---------------------------------------------------------------------------
# 1. Build
# ---------------------------------------------------------------------------
Write-Host "Building bee-worker..."
Push-Location $WorkerDir
npm install --frozen-lockfile
npm run build
Pop-Location

# ---------------------------------------------------------------------------
# 2. Create directories
# ---------------------------------------------------------------------------
foreach ($dir in @($SecretsDir, $AuditDir, $LogDir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-Host "Directory ensured: $dir"
}

# ---------------------------------------------------------------------------
# 3. Apply NTFS ACL — Full Control for Duong only, strip Users and Everyone
# ---------------------------------------------------------------------------
foreach ($target in @($SecretsDir, $AuditDir)) {
    # Remove inheritance, remove all inherited ACEs
    icacls $target /inheritance:r | Out-Null
    # Strip broad groups if present (errors are silenced — they may not exist)
    icacls $target /remove "BUILTIN\Users"  2>$null | Out-Null
    icacls $target /remove "Everyone"       2>$null | Out-Null
    icacls $target /remove "NT AUTHORITY\Authenticated Users" 2>$null | Out-Null
    # Grant current user (Duong) Full Control
    icacls $target /grant:r "${Username}:(OI)(CI)F" | Out-Null
    Write-Host "NTFS ACL applied to $target (Full Control: $Username only)"
}

# ---------------------------------------------------------------------------
# 4. Write env file template (only if not already present — protect real creds)
# ---------------------------------------------------------------------------
if (-not (Test-Path $EnvFile)) {
    $template = @"
# bee-worker environment variables
# Fill in real values before starting the service.
# This file is protected by NTFS ACL — only $Username has access.

# Path to Firebase Admin SDK service account JSON
GOOGLE_APPLICATION_CREDENTIALS=$($env:USERPROFILE)\bee\secrets\firebase-admin.json

# Firebase project ID
BEE_FIREBASE_PROJECT_ID=myapps-b31ea

# Firebase Storage bucket
BEE_STORAGE_BUCKET=myapps-b31ea.appspot.com

# Ephemeral job scratch directory
BEE_WORK_DIR=$($env:TEMP)\bee

# Path to claude.cmd (Claude Code CLI)
BEE_CLAUDE_BIN=C:\Users\$($env:USERNAME)\AppData\Roaming\npm\claude.cmd

# Path to per-user Python binary
BEE_PYTHON_BIN=C:\Users\$($env:USERNAME)\AppData\Local\Programs\Python\Python312\python.exe

# Path to runlock file (shared with coder-worker if both run on same machine)
BEE_RUNLOCK_PATH=$($env:USERPROFILE)\.claude-runlock\claude.lock

# Audit log directory — outside worker writable tree, Claude subprocess cannot reach it
BEE_AUDIT_LOG_DIR=$($env:USERPROFILE)\bee-audit\

# Hard kill timeout for claude -p subprocess (milliseconds) — 25 minutes
BEE_JOB_TIMEOUT_MS=1500000

# Sister's Firebase Auth UID — defense-in-depth filter, must match Firestore rules
BEE_SISTER_UID=SISTER_UID_PLACEHOLDER
"@
    Set-Content -Path $EnvFile -Value $template -Encoding UTF8
    Write-Host "Env file template written: $EnvFile"
    Write-Host "  -> Fill in real values before starting the service."
} else {
    Write-Host "Env file already exists, skipping template write: $EnvFile"
}

# Re-apply ACL to env file itself (in case it existed before)
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
    & $NssmPath stop    $ServiceName confirm
    & $NssmPath remove  $ServiceName confirm
}

Write-Host "Installing service $ServiceName..."
& $NssmPath install $ServiceName $NodePath $MainJs

& $NssmPath set $ServiceName AppDirectory       $WorkerDir
& $NssmPath set $ServiceName AppEnvironmentExtra "NODE_ENV=production" "DOTENV_CONFIG_PATH=$EnvFile"
& $NssmPath set $ServiceName AppStdout          (Join-Path $LogDir "stdout.log")
& $NssmPath set $ServiceName AppStderr          (Join-Path $LogDir "stderr.log")
& $NssmPath set $ServiceName AppRotateFiles     1
& $NssmPath set $ServiceName AppRotateBytes     10485760   # 10 MB
& $NssmPath set $ServiceName Start              SERVICE_AUTO_START
& $NssmPath set $ServiceName DisplayName        $DisplayName
& $NssmPath set $ServiceName Description        $Description
& $NssmPath set $ServiceName ObjectName         $Username

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
Write-Host "Audit dir   : $AuditDir"
Write-Host "Env file    : $EnvFile"
Write-Host "Logs        : $LogDir"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Edit $EnvFile and fill in real values."
Write-Host "  2. Put Firebase service account JSON at:"
Write-Host "       $($env:USERPROFILE)\bee\secrets\firebase-admin.json"
Write-Host "  3. Replace BEE_SISTER_UID with sister's Firebase Auth UID."
Write-Host "  4. Run: nssm restart $ServiceName"
