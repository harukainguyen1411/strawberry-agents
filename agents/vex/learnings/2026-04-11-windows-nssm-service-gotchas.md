# Windows NSSM Service Setup Gotchas

**Date:** 2026-04-11
**Agent:** Vex
**Applicable to:** Any agent setting up NSSM services on Windows

## Lessons

### 1. Em dashes break Windows PowerShell 5.1 parsing
PS1 files with em dashes (`—`, U+2014) in double-quoted strings or Write-Error/Write-Host strings fail to parse on PowerShell 5.1 unless the file has a UTF-8 BOM. Replace em dashes with hyphens in all PS1 string literals. Comments are safe.

### 2. NSSM defaults to LocalSystem — grant SYSTEM read to secret files
Services installed without `ObjectName` run as `NT AUTHORITY\SYSTEM`. If secret files have `icacls /inheritance:r` applied (removing inheritance), SYSTEM won't inherit directory-level grants. Grant SYSTEM directly on the file:
```powershell
icacls "path\to\secret.env" /grant "SYSTEM:(R)"
```

### 3. Git blocks SYSTEM from repos owned by another user
Add the repo to the system-wide git safe.directory (applies to all users including SYSTEM):
```powershell
Add-Content "C:\Program Files\Git\etc\gitconfig" "`n[safe]`n`tdirectory = C:/path/to/repo"
```

### 4. `sc` in PowerShell is Set-Content, not sc.exe
Always use `sc.exe` explicitly when managing services from PowerShell.

### 5. `$env` is a reserved prefix in PowerShell
Don't use `$env` as a variable name — it shadows the environment variable provider. Use `$envf`, `$envFile`, etc.

### 6. AppEnvironmentExtra with two strings needs backtick-n when run ad-hoc
When running `nssm set svc AppEnvironmentExtra` interactively in PowerShell (not from a PS1 script), pass multiple env vars as a single newline-delimited string:
```powershell
nssm set $svc AppEnvironmentExtra "KEY1=val1`nKEY2=val2"
```
From inside a PS1 script, `"arg1" "arg2"` as separate arguments works correctly.

### 7. Cloudflare quick tunnels are ephemeral
`cloudflared tunnel --url http://localhost:PORT` gives a `trycloudflare.com` URL that changes on every restart. Install as NSSM service for persistence, but URL still changes. For a stable URL, use a named tunnel with a Cloudflare account.
