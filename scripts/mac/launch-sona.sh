#!/usr/bin/env bash
# Launch Sona on Mac — Remote Control + dangerously-skip-permissions
# Delegates to coordinator-boot.sh to export identity env vars (INV-4).
# CLAUDE_AGENT_NAME and siblings are set before claude spawns.
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
export CLAUDE_AGENT_NAME="Sona"
export STRAWBERRY_AGENT="Sona"
export STRAWBERRY_CONCERN="work"
cd "$REPO_DIR"
exec claude --dangerously-skip-permissions --remote-control --agent Sona
