#!/bin/bash
# Migrate operational files from git repo to ~/.strawberry/ops/
# Run once. Safe to re-run — skips existing files.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPS_ROOT="$HOME/.strawberry/ops"

echo "Migrating operational files from $REPO_ROOT to $OPS_ROOT"

# Create ops directory structure
mkdir -p "$OPS_ROOT"/{conversations,health/heartbeats,inbox-queue}
chmod 700 "$OPS_ROOT"

# Agent list
AGENTS=(evelynn pyke syndra bard katarina ornn fiora lissandra reksai swain neeko zoe caitlyn)

for agent in "${AGENTS[@]}"; do
  mkdir -p "$OPS_ROOT/inbox/$agent"

  # Migrate inbox files
  if [ -d "$REPO_ROOT/agents/$agent/inbox" ]; then
    for f in "$REPO_ROOT/agents/$agent/inbox"/*.md; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"
      if [ ! -f "$OPS_ROOT/inbox/$agent/$base" ]; then
        cp "$f" "$OPS_ROOT/inbox/$agent/$base"
        echo "  inbox: $agent/$base"
      fi
    done
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
fi

# Migrate health files
if [ -d "$REPO_ROOT/agents/health" ]; then
  for f in "$REPO_ROOT/agents/health"/*.json; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    if [ ! -f "$OPS_ROOT/health/$base" ]; then
      cp "$f" "$OPS_ROOT/health/$base"
      echo "  health: $base"
    fi
  done
  if [ -f "$REPO_ROOT/agents/health/heartbeat.sh" ]; then
    cp "$REPO_ROOT/agents/health/heartbeat.sh" "$OPS_ROOT/health/heartbeat.sh"
    chmod +x "$OPS_ROOT/health/heartbeat.sh"
    echo "  health: heartbeat.sh"
  fi
fi

echo ""
echo "Migration complete. Ops files are now in $OPS_ROOT"
echo "The .gitignore has been updated to exclude these paths from the repo."
echo "You can safely delete the migrated files from the repo once verified."
