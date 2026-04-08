<#
.SYNOPSIS
    Kill any running Evelynn Claude Code session and relaunch her fresh.

.DESCRIPTION
    Yuumi's one job. Finds any process whose command line contains
    `--remote-control "Evelynn"` (case-insensitive on the name), stops it,
    and relaunches Evelynn via windows-mode\launch-evelynn.bat.

    HARD RULE: this script MUST NOT touch any other Claude Code session.
    It explicitly filters on the exact `--remote-control "Evelynn"` token
    to avoid killing Yuumi herself or any unrelated `claude` process.

.NOTES
    Intended invoker: Yuumi. Duong launches Yuumi as a second Remote Control
    session; when he asks her to restart Evelynn, she runs this script.

    Exit codes:
      0 — success (Evelynn relaunched, whether or not an old process existed)
      1 — failure to launch the new process
      2 — unexpected error
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    Write-Host "restart-evelynn: repo root = $repoRoot"

    # Filter: only processes whose CommandLine contains the literal token
    # `--remote-control "Evelynn"` (case-insensitive on "Evelynn"). Using
    # a regex with the quotes embedded so we can't accidentally match
    # `--remote-control "EvelynnFoo"` or `--remote-control "Yuumi"`.
    $pattern = '--remote-control\s+"Evelynn"'

    $allProcs = Get-CimInstance Win32_Process -Filter "Name = 'claude.exe' OR Name = 'claude'"
    # Fall back to broader query if the Name filter misses (claude may run via node)
    if (-not $allProcs) {
        $allProcs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine }
    }

    $evelynnProcs = $allProcs | Where-Object {
        $_.CommandLine -and ($_.CommandLine -imatch $pattern)
    }

    if ($evelynnProcs) {
        foreach ($p in $evelynnProcs) {
            Write-Host ("restart-evelynn: found Evelynn PID {0}" -f $p.ProcessId)
            Write-Host ("restart-evelynn:   cmdline = {0}" -f $p.CommandLine)
            Write-Host "restart-evelynn: stopping..."
            try {
                Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
            } catch {
                Write-Warning ("restart-evelynn: Stop-Process failed for PID {0}: {1}" -f $p.ProcessId, $_.Exception.Message)
            }
        }
        # Give Windows a beat to actually reap the process.
        Start-Sleep -Seconds 2
    } else {
        Write-Host "restart-evelynn: no Evelynn process running, will launch fresh."
    }

    # Relaunch detached so this script returns control immediately.
    $launcher = Join-Path $repoRoot 'windows-mode\launch-evelynn.bat'
    if (-not (Test-Path $launcher)) {
        Write-Error "restart-evelynn: launcher not found at $launcher"
        exit 1
    }

    Write-Host "restart-evelynn: launching $launcher (detached)..."
    Start-Process -FilePath 'cmd.exe' `
                  -ArgumentList '/c', $launcher `
                  -WorkingDirectory $repoRoot `
                  -WindowStyle Normal | Out-Null

    Write-Host "restart-evelynn: Evelynn relaunched. Reconnect via Claude Desktop's Remote Control panel."
    exit 0
}
catch {
    Write-Error ("restart-evelynn: unexpected error: {0}" -f $_.Exception.Message)
    exit 2
}
