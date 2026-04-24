# Launch Sona in Windows Mode — Remote Control + dangerously-skip-permissions
# See windows-mode/README.md for details
# Identity env vars exported before claude spawns (INV-4).
$env:CLAUDE_AGENT_NAME = 'Sona'
$env:STRAWBERRY_AGENT  = 'Sona'
$env:STRAWBERRY_CONCERN = 'work'
Set-Location -Path (Join-Path $PSScriptRoot '..')
claude --dangerously-skip-permissions --remote-control --agent Sona
