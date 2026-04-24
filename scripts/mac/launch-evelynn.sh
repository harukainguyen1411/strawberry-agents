#!/usr/bin/env bash
# Launch Evelynn on Mac — Remote Control + dangerously-skip-permissions
# Delegates to coordinator-boot.sh to export identity env vars (INV-4).
# CLAUDE_AGENT_NAME and siblings are set before claude spawns.
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
export CLAUDE_AGENT_NAME="Evelynn"
export STRAWBERRY_AGENT="Evelynn"
export STRAWBERRY_CONCERN="personal"
cd "$REPO_DIR"
exec claude --dangerously-skip-permissions --remote-control --agent Evelynn
