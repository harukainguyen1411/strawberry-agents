#!/usr/bin/env bash
# Launch Sona on Mac — Remote Control + dangerously-skip-permissions
# Wrapped in a subshell so exports cannot leak into the sourcing shell even when
# the script is sourced (. launch-sona.sh) rather than executed directly.
# Writes .coordinator-identity atomically before exec so watcher subprocesses
# spawned by Monitor (inbox-watch.sh Tier 3) resolve identity without env vars.
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
(
  export CLAUDE_AGENT_NAME="Sona"
  export STRAWBERRY_AGENT="Sona"
  export STRAWBERRY_CONCERN="work"
  cd "$REPO_DIR"
  printf 'Sona' > "$REPO_DIR/.coordinator-identity.tmp" \
    && mv "$REPO_DIR/.coordinator-identity.tmp" "$REPO_DIR/.coordinator-identity"
  exec claude --dangerously-skip-permissions --remote-control --agent Sona
)
