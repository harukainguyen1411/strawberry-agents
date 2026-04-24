#!/usr/bin/env bash
# Launch Sona on Mac — Remote Control + dangerously-skip-permissions
# Sets CLAUDE_AGENT_NAME / STRAWBERRY_AGENT / STRAWBERRY_CONCERN identity env
# vars inline (INV-4), then execs `claude` directly.
# Does NOT source coordinator-boot.sh — memory consolidation and startup reads
# are skipped here; they happen inside the coordinator session via SessionStart.
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
export CLAUDE_AGENT_NAME="Sona"
export STRAWBERRY_AGENT="Sona"
export STRAWBERRY_CONCERN="work"
cd "$REPO_DIR"
exec claude --dangerously-skip-permissions --remote-control --agent Sona
