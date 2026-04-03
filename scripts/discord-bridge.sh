#!/usr/bin/env bash
# discord-bridge.sh — Watches event queue, spawns claude -p per event
set -euo pipefail

export PATH="$HOME/.npm-global/bin:$PATH"

DATA_DIR="${DATA_DIR:-/home/runner/data}"
EVENTS_DIR="$DATA_DIR/discord-events"
PROCESSED_DIR="$DATA_DIR/discord-processed"
RESPONSES_DIR="$DATA_DIR/discord-responses"
STRAWBERRY_DIR="${STRAWBERRY_DIR:-/home/runner/strawberry}"
MIN_INTERVAL=30  # seconds between claude invocations

mkdir -p "$EVENTS_DIR" "$PROCESSED_DIR" "$RESPONSES_DIR"

last_invocation=0

process_event() {
  local file="$1"
  local basename
  basename=$(basename "$file")

  # Rate limiting
  local now
  now=$(date +%s)
  local elapsed=$(( now - last_invocation ))
  if [ "$elapsed" -lt "$MIN_INTERVAL" ]; then
    local wait=$(( MIN_INTERVAL - elapsed ))
    echo "[bridge] Rate limit: waiting ${wait}s"
    sleep "$wait"
  fi

  echo "[bridge] Processing: $basename"

  # Extract fields from JSON
  local thread_id thread_name content
  thread_id=$(jq -r '.threadId' "$file")
  thread_name=$(jq -r '.threadName' "$file")
  content=$(jq -r '.content' "$file")

  # Build prompt for Evelynn
  local prompt
  prompt=$(cat <<PROMPT
[Discord suggestion from #suggestions forum]

<event>
Title: ${thread_name}
Content: ${content}
Thread ID: ${thread_id}
</event>

Triage this suggestion. Decide if it's actionable (bug, feature, enhancement) or should be declined (question, off-topic, unclear). If actionable, delegate to the appropriate agent. Reply with a short summary for the Discord thread.
PROMPT
)

  # Invoke Claude as Evelynn
  local result
  last_invocation=$(date +%s)
  result=$(cd "$STRAWBERRY_DIR" && claude -p "$prompt" --max-turns 3 --output-format text < /dev/null 2>&1) || true

  if [ -n "$result" ]; then
    # Write response JSON for the relay bot to pick up
    local response_file="$RESPONSES_DIR/${thread_id}-$(date +%s).json"
    jq -n --arg threadId "$thread_id" --arg message "$result" \
      '{threadId: $threadId, message: $message}' > "$response_file"
    echo "[bridge] Response written for thread $thread_id"
  else
    echo "[bridge] No result from Claude for $basename"
  fi

  # Archive the event
  mv "$file" "$PROCESSED_DIR/$basename"
}

echo "[bridge] Watching $EVENTS_DIR for events..."

# Process existing events first
for f in "$EVENTS_DIR"/*.json; do
  [ -f "$f" ] || continue
  process_event "$f"
done

# Watch for new events using inotifywait if available, otherwise poll
if command -v inotifywait &>/dev/null; then
  inotifywait -m -e close_write "$EVENTS_DIR" --format '%f' | while read -r filename; do
    [ "${filename##*.}" = "json" ] || continue
    local_file="$EVENTS_DIR/$filename"
    [ -f "$local_file" ] || continue
    process_event "$local_file"
  done
else
  echo "[bridge] inotifywait not found, falling back to polling (5s interval)"
  while true; do
    for f in "$EVENTS_DIR"/*.json; do
      [ -f "$f" ] || continue
      process_event "$f"
    done
    sleep 5
  done
fi
