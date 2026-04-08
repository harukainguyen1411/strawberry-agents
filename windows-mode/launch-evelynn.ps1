# Launch Evelynn in Windows Mode — Remote Control + dangerously-skip-permissions
# See windows-mode/README.md for details
Set-Location -Path (Join-Path $PSScriptRoot '..')
claude --dangerously-skip-permissions --remote-control "Evelynn"
