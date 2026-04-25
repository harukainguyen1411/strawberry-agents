# Launch Sona in Windows Mode — Remote Control + dangerously-skip-permissions
# Wrapped in a script block so env var assignments are scoped to the block and
# do not persist in the calling PowerShell session (no leak on dot-sourcing).
# Writes .coordinator-identity atomically for inbox-watch.sh Tier 3 fallback.
& {
  $env:CLAUDE_AGENT_NAME  = 'Sona'
  $env:STRAWBERRY_AGENT   = 'Sona'
  $env:STRAWBERRY_CONCERN = 'work'
  $repoDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..'))
  Set-Location -Path $repoDir
  $tmp = Join-Path $repoDir '.coordinator-identity.tmp'
  Set-Content -Path $tmp -Value 'Sona' -NoNewline
  Move-Item -Path $tmp -Destination (Join-Path $repoDir '.coordinator-identity') -Force
  & claude --dangerously-skip-permissions --remote-control --agent Sona
}
