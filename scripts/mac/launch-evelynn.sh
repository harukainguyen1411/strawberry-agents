#!/usr/bin/env bash
# Launch Evelynn on Mac — Remote Control + dangerously-skip-permissions
# Wrapped in a subshell so exports cannot leak into the sourcing shell even when
# the script is sourced (. launch-evelynn.sh) rather than executed directly.
# Writes .coordinator-identity atomically before exec so watcher subprocesses
# spawned by Monitor (inbox-watch.sh Tier 3) resolve identity without env vars.
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
(
  export CLAUDE_AGENT_NAME="Evelynn"
  export STRAWBERRY_AGENT="Evelynn"
  export STRAWBERRY_CONCERN="personal"
  cd "$REPO_DIR"
  printf 'Evelynn' > "$REPO_DIR/.coordinator-identity.tmp" \
    && mv "$REPO_DIR/.coordinator-identity.tmp" "$REPO_DIR/.coordinator-identity"
  exec claude --dangerously-skip-permissions --remote-control --agent Evelynn
)
