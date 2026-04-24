#!/usr/bin/env bash
# Launch Evelynn on Mac — Remote Control + dangerously-skip-permissions
# Sets CLAUDE_AGENT_NAME / STRAWBERRY_AGENT / STRAWBERRY_CONCERN identity env
# vars inline (INV-4), sources coordinator-boot.sh for memory consolidation and
# startup reads, then execs `claude` with --dangerously-skip-permissions and
# --remote-control layered in (flags not supported by coordinator-boot.sh exec).
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
export CLAUDE_AGENT_NAME="Evelynn"
export STRAWBERRY_AGENT="Evelynn"
export STRAWBERRY_CONCERN="personal"
cd "$REPO_DIR"
exec claude --dangerously-skip-permissions --remote-control --agent Evelynn
