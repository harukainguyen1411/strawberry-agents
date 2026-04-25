# Strawberry coordinator launchers.
# Source from ~/.zshrc:
#   source ~/Documents/Personal/strawberry-agents/scripts/mac/aliases.sh
#
# Both aliases invoke coordinator-boot.sh, which:
#   - passes CLAUDE_AGENT_NAME, STRAWBERRY_AGENT, STRAWBERRY_CONCERN via `env` to the
#     exec'd claude process (never exported into the parent shell)
#   - runs memory-consolidate.sh
#   - exec's claude --agent <Name>
# Identity is always explicit (INV-4 — no hardcoded .agent fallback).

alias evelynn='bash ~/Documents/Personal/strawberry-agents/scripts/coordinator-boot.sh Evelynn'
alias sona='bash ~/Documents/Personal/strawberry-agents/scripts/coordinator-boot.sh Sona'
