# Launch Evelynn in Windows Mode — Remote Control + dangerously-skip-permissions
# See windows-mode/README.md for details
# Identity env vars exported before claude spawns (INV-4).
$env:CLAUDE_AGENT_NAME = 'Evelynn'
$env:STRAWBERRY_AGENT  = 'Evelynn'
$env:STRAWBERRY_CONCERN = 'personal'
Set-Location -Path (Join-Path $PSScriptRoot '..')
claude --dangerously-skip-permissions --remote-control --agent Evelynn
