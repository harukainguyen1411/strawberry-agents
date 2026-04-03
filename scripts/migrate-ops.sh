#!/bin/bash
# Migrate operational files from git repo to ~/.strawberry/ops/
# Run once. Safe to re-run — skips existing files.
# Use --clean to git rm originals after migration.

set -euo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPS_ROOT="$HOME/.strawberry/ops"
CLEAN=false

if [ "${1:-}" = "--clean" ]; then
  CLEAN=true
fi

echo "Migrating operational files from $REPO_ROOT to $OPS_ROOT"

# Create ops directory structure
mkdir -p "$OPS_ROOT"/{conversations,health/heartbeats,inbox-queue}

# Discover agents dynamically from repo
MIGRATED_PATHS=()

for agent_dir in "$REPO_ROOT"/agents/*/; do
  [ -d "$agent_dir" ] || continue
  agent="$(basename "$agent_dir")"

  # Skip shared directories (memory/, conversations/, etc.)
  [ "$agent" = "memory" ] && continue
  [ "$agent" = "conversations" ] && continue
  [ "$agent" = "health" ] && continue
  [ "$agent" = "inbox-queue" ] && continue

  mkdir -p "$OPS_ROOT/inbox/$agent"

  # Migrate inbox files
  if [ -d "$agent_dir/inbox" ]; then
    for f in "$agent_dir/inbox"/*.md; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"
      if [ ! -f "$OPS_ROOT/inbox/$agent/$base" ]; then
        cp "$f" "$OPS_ROOT/inbox/$agent/$base"
        echo "  inbox: $agent/$base"
      fi
    done
    MIGRATED_PATHS+=("agents/$agent/inbox")
  fi
done

# Migrate conversations
if [ -d "$REPO_ROOT/agents/conversations" ]; then
  for f in "$REPO_ROOT/agents/conversations"/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    if [ ! -f "$OPS_ROOT/conversations/$base" ]; then
      cp "$f" "$OPS_ROOT/conversations/$base"
      echo "  conversation: $base"
    fi
  done
  MIGRATED_PATHS+=("agents/conversations")
fi

# Migrate health JSON files (not heartbeat.sh — that's a tool, stays in repo)
if [ -d "$REPO_ROOT/agents/health" ]; then
  for f in "$REPO_ROOT/agents/health"/*.json; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    if [ ! -f "$OPS_ROOT/health/$base" ]; then
      cp "$f" "$OPS_ROOT/health/$base"
      echo "  health: $base"
    fi
  done
  MIGRATED_PATHS+=("agents/health/*.json")
fi

# Migrate inbox-queue
if [ -d "$REPO_ROOT/agents/inbox-queue" ]; then
  for f in "$REPO_ROOT/agents/inbox-queue"/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    if [ ! -f "$OPS_ROOT/inbox-queue/$base" ]; then
      cp "$f" "$OPS_ROOT/inbox-queue/$base"
      echo "  inbox-queue: $base"
    fi
  done
  MIGRATED_PATHS+=("agents/inbox-queue")
fi

echo ""
echo "Migration complete. Ops files are now in $OPS_ROOT"

if [ "$CLEAN" = true ]; then
  echo "Cleaning up migrated originals from repo..."
  cd "$REPO_ROOT"
  for p in "${MIGRATED_PATHS[@]}"; do
    git rm -r --quiet "$p" 2>/dev/null || true
  done
  echo "Originals removed. Commit the cleanup when ready."
else
  echo "To remove originals from the repo, re-run with --clean"
fi
