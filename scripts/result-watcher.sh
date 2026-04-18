#!/usr/bin/env bash
# result-watcher.sh — Monitors agent completion, posts follow-up responses to Discord
# This handles responses from multi-turn delegations (tier 2+) that complete asynchronously.
set -euo pipefail

DATA_DIR="${DATA_DIR:-/home/runner/data}"
RESPONSES_DIR="$DATA_DIR/discord-responses"

mkdir -p "$RESPONSES_DIR"

echo "[result-watcher] Watching $RESPONSES_DIR for delayed responses..."

# The relay bot's built-in fs.watch handles immediate responses.
# This script exists for PM2 process management and as a fallback
# if the relay bot restarts and misses fs.watch events.

# On startup, nudge the relay bot by touching any pending response files
nudge_pending() {
  for f in "$RESPONSES_DIR"/*.json; do
    [ -f "$f" ] || continue
    echo "[result-watcher] Found pending response: $(basename "$f")"
    # Touch to re-trigger fs.watch in the relay bot
    touch "$f"
  done
}

nudge_pending

if command -v inotifywait &>/dev/null; then
  inotifywait -m -e close_write "$RESPONSES_DIR" --format '%f' | while read -r filename; do
    [ "${filename##*.}" = "json" ] || continue
    echo "[result-watcher] New response detected: $filename"
    # The relay bot handles posting. If it doesn't pick it up within 10s, re-touch.
    sleep 10
    local_file="$RESPONSES_DIR/$filename"
    if [ -f "$local_file" ]; then
      echo "[result-watcher] Response still pending, nudging relay: $filename"
      touch "$local_file"
    fi
  done
else
  echo "[result-watcher] inotifywait not found, polling every 10s"
  while true; do
    nudge_pending
    sleep 10
  done
fi
