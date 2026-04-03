#!/usr/bin/env bash
# discord-bridge.sh — Two-pass event processor
# Pass 1 (triage): cheap, text-only, decides if actionable
# Pass 2 (delegation): full Evelynn with tools, agent-manager, codebase access
set -euo pipefail

export PATH="$HOME/.npm-global/bin:$PATH"

DATA_DIR="${DATA_DIR:-/home/runner/data}"
EVENTS_DIR="$DATA_DIR/discord-events"
PROCESSED_DIR="$DATA_DIR/discord-processed"
RESPONSES_DIR="$DATA_DIR/discord-responses"
STRAWBERRY_DIR="${STRAWBERRY_DIR:-/home/runner/strawberry}"
LOCK_FILE="$DATA_DIR/.delegation-lock"
MIN_INTERVAL=30

mkdir -p "$EVENTS_DIR" "$PROCESSED_DIR" "$RESPONSES_DIR"

last_invocation=0

# --- Triage system prompts ---

TRIAGE_PROMPT_NEW='You are a triage assistant for the Strawberry project. Evaluate this Discord suggestion and respond with ONLY valid JSON (no markdown fences, no explanation) matching this schema:
{"verdict":"actionable|decline|question","category":"bug|feature|enhancement|question|off-topic","confidence":"high|medium|low","delegate_to":"katarina|ornn|fiora|null","discord_response":"Short friendly message for the Discord thread","summary":"One-line summary for delegation"}
- "actionable": clear bug, feature request, or enhancement that can be implemented
- "decline": off-topic, unclear, or not something to build
- "question": user is asking a question, answer it directly in discord_response
- delegate_to: katarina for quick tasks, ornn for new features, fiora for bugs/refactors, null if unsure'

TRIAGE_PROMPT_REPLY='You are a triage assistant for the Strawberry project. This is a follow-up reply in an existing suggestion thread. Respond with ONLY valid JSON (no markdown fences, no explanation) matching this schema:
{"verdict":"followup_actionable|question|acknowledge","confidence":"high|medium|low","discord_response":"Short friendly response","summary":"One-line summary if actionable"}
- "followup_actionable": user is providing detail, confirming they want something built, or adding a new request
- "question": user is asking something, answer in discord_response
- "acknowledge": thanks, agreement, or chatter — just respond politely'

# --- Rate limiter ---
rate_limit() {
  local now
  now=$(date +%s)
  local elapsed=$(( now - last_invocation ))
  if [ "$elapsed" -lt "$MIN_INTERVAL" ]; then
    local wait=$(( MIN_INTERVAL - elapsed ))
    echo "[bridge] Rate limit: waiting ${wait}s"
    sleep "$wait"
  fi
  last_invocation=$(date +%s)
}

# --- Write a response file for the bot to pick up ---
write_response() {
  local thread_id="$1"
  local message="$2"
  local response_file="$RESPONSES_DIR/${thread_id}-$(date +%s).json"
  jq -n --arg threadId "$thread_id" --arg message "$message" \
    '{threadId: $threadId, message: $message}' > "$response_file"
}

# --- Triage pass ---
run_triage() {
  local event_type="$1"
  local thread_name="$2"
  local content="$3"

  local system_prompt
  if [ "$event_type" = "forum_post" ]; then
    system_prompt="$TRIAGE_PROMPT_NEW"
  else
    system_prompt="$TRIAGE_PROMPT_REPLY"
  fi

  local user_prompt="Thread: ${thread_name}
Content: ${content}"

  local result
  result=$(cd /tmp && claude -p "$user_prompt" \
    --max-turns 1 \
    --output-format text \
    --system-prompt "$system_prompt" \
    --disallowedTools Bash Read Write Edit Glob Grep Agent \
    < /dev/null 2>&1) || true

  echo "$result"
}

# --- Delegation pass (runs in background) ---
run_delegation() {
  local thread_id="$1"
  local thread_name="$2"
  local content="$3"
  local triage_json="$4"

  local delegate_to
  delegate_to=$(echo "$triage_json" | jq -r '.delegate_to // "appropriate agent"')
  local summary
  summary=$(echo "$triage_json" | jq -r '.summary // "No summary"')

  local response_file="$RESPONSES_DIR/${thread_id}-delegation-$(date +%s).json"

  # Write the delegation prompt to a temp file to avoid shell escaping issues
  local prompt_file
  prompt_file=$(mktemp /tmp/delegation-XXXXXX.txt)
  cat > "$prompt_file" <<DELEGATION
[Discord delegation — suggestion already triaged as actionable]

Thread: ${thread_name} (ID: ${thread_id})
Content: ${content}
Triage summary: ${summary}
Suggested agent: ${delegate_to}

Delegate this to the appropriate agent using your agent-manager tools. When delegation is complete, write your Discord follow-up response as a JSON file to: ${response_file}

The JSON must be: {"threadId": "${thread_id}", "message": "your response here"}

Use the Write tool to create that file. Keep your Discord message under 2000 characters.
DELEGATION

  echo "[bridge] Starting delegation pass for thread $thread_id"

  # Lock — only one delegation at a time
  if [ -f "$LOCK_FILE" ]; then
    local lock_pid
    lock_pid=$(cat "$LOCK_FILE")
    if kill -0 "$lock_pid" 2>/dev/null; then
      echo "[bridge] Delegation already running (pid $lock_pid), queueing $thread_id"
      # Re-queue by not archiving — it'll be picked up next poll
      rm -f "$prompt_file"
      return 1
    else
      echo "[bridge] Stale lock from pid $lock_pid, removing"
      rm -f "$LOCK_FILE"
    fi
  fi

  # Run delegation in background with timeout
  (
    echo $$ > "$LOCK_FILE"
    local delegation_result
    delegation_result=$(cd "$STRAWBERRY_DIR" && timeout 600 claude -p "$(cat "$prompt_file")" \
      --max-turns 25 \
      < /dev/null 2>&1) || true

    rm -f "$prompt_file"

    # Check if Evelynn wrote the response file
    if [ ! -f "$response_file" ]; then
      echo "[bridge] Delegation did not produce a response file, writing fallback"
      # If delegation produced stdout, use it as fallback
      if [ -n "$delegation_result" ]; then
        jq -n --arg threadId "$thread_id" --arg message "${delegation_result:0:2000}" \
          '{threadId: $threadId, message: $message}' > "$response_file"
      else
        jq -n --arg threadId "$thread_id" --arg message "I delegated this but didn't get a result back. An admin has been notified." \
          '{threadId: $threadId, message: $message}' > "$response_file"
      fi
    fi

    rm -f "$LOCK_FILE"
    echo "[bridge] Delegation complete for thread $thread_id"
  ) &

  return 0
}

# --- Process a single event ---
process_event() {
  local file="$1"
  local basename
  basename=$(basename "$file")

  rate_limit

  echo "[bridge] Processing: $basename"

  # Extract fields
  local thread_id thread_name content event_type
  thread_id=$(jq -r '.threadId' "$file")
  thread_name=$(jq -r '.threadName' "$file")
  content=$(jq -r '.content' "$file")
  event_type=$(jq -r '.type // "forum_post"' "$file")

  # Pass 1: Triage
  echo "[bridge] Triage pass for $thread_id ($event_type)"
  local triage_output
  triage_output=$(run_triage "$event_type" "$thread_name" "$content")

  # Try to parse as JSON
  local verdict discord_response
  if echo "$triage_output" | jq -e . >/dev/null 2>&1; then
    verdict=$(echo "$triage_output" | jq -r '.verdict // "decline"')
    discord_response=$(echo "$triage_output" | jq -r '.discord_response // "Thanks for the suggestion!"')
  else
    echo "[bridge] Triage output was not valid JSON, treating as decline"
    echo "[bridge] Raw output: $triage_output"
    verdict="decline"
    discord_response="Thanks for the suggestion! I'll take a look."
  fi

  echo "[bridge] Triage verdict: $verdict"

  # Act on verdict
  case "$verdict" in
    actionable|followup_actionable)
      # Post immediate ack
      local delegate_to
      delegate_to=$(echo "$triage_output" | jq -r '.delegate_to // "the team"' 2>/dev/null || echo "the team")
      write_response "$thread_id" "$discord_response"

      # Pass 2: Delegation (background)
      if ! run_delegation "$thread_id" "$thread_name" "$content" "$triage_output"; then
        write_response "$thread_id" "This is queued — I'm currently working on another task. I'll get to this shortly."
      fi
      ;;
    *)
      # decline, question, acknowledge — just post the response
      write_response "$thread_id" "$discord_response"
      ;;
  esac

  # Archive the event
  mv "$file" "$PROCESSED_DIR/$basename"
}

# --- Main loop ---
echo "[bridge] Watching $EVENTS_DIR for events..."

# Process existing events first
for f in "$EVENTS_DIR"/*.json; do
  [ -f "$f" ] || continue
  process_event "$f"
done

# Poll for new events
if command -v inotifywait &>/dev/null; then
  inotifywait -m -e close_write "$EVENTS_DIR" --format '%f' | while read -r filename; do
    [ "${filename##*.}" = "json" ] || continue
    local_file="$EVENTS_DIR/$filename"
    [ -f "$local_file" ] || continue
    process_event "$local_file"
  done
else
  echo "[bridge] Polling mode (5s interval)"
  while true; do
    for f in "$EVENTS_DIR"/*.json; do
      [ -f "$f" ] || continue
      process_event "$f"
    done
    sleep 5
  done
fi
