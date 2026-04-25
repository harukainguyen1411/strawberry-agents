#!/usr/bin/env bash
# Launch Sona on Mac — Remote Control + dangerously-skip-permissions
# Passes CLAUDE_AGENT_NAME / STRAWBERRY_AGENT / STRAWBERRY_CONCERN identity env
# vars to the exec'd process via `env` (INV-4) — never exported into the parent shell.
# Does NOT source coordinator-boot.sh — memory consolidation and startup reads
# are skipped here; they happen inside the coordinator session via SessionStart.
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_DIR"
exec env CLAUDE_AGENT_NAME="Sona" STRAWBERRY_AGENT="Sona" STRAWBERRY_CONCERN="work" \
  claude --dangerously-skip-permissions --remote-control --agent Sona
