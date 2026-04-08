---
title: Launch verification & heartbeat visibility
status: proposed
owner: bard
created: 2026-04-05
gdoc_id: 1fgOFYmF73Aq6m5OpUO_syDKyVQa9RqvgKXx0Mh9ccBQ
gdoc_url: https://docs.google.com/document/d/1fgOFYmF73Aq6m5OpUO_syDKyVQa9RqvgKXx0Mh9ccBQ/edit
---

# Problem

`launch_agent` returns `"launched"` immediately after creating the iTerm window and sending the startup command. It doesn't verify Claude Code actually started. Today Ornn was launched 5 times — each time the tool reported success, but Claude crashed immediately (likely a zsh error). No feedback reached the caller.

# Solution

Five improvements, ordered by impact:

## 1. Launch verification — poll for heartbeat after launch

After sending the startup greeting, `launch_agent` polls the registry for a heartbeat from the launched agent. Agents call `heartbeat.sh` in their startup sequence, so a heartbeat appearing within ~30s confirms Claude Code is running and the agent loaded.

```python
# After sending startup greeting, poll for heartbeat confirmation
max_wait = 30  # seconds
poll_interval = 3
confirmed = False
for _ in range(max_wait // poll_interval):
    await asyncio.sleep(poll_interval)
    registry = _read_registry()
    entry = registry.get(recipient, {})
    hb = entry.get('last_heartbeat', '')
    if hb and not _is_stale(hb):
        confirmed = True
        break

result['verified'] = confirmed
if not confirmed:
    result['status'] = 'launched_unverified'
    result['warning'] = f'{greeting} did not send a heartbeat within {max_wait}s. Claude may have failed to start — check the iTerm window.'
```

The caller sees `"launched"` (verified) or `"launched_unverified"` (no heartbeat). This doesn't block — it's informational. Evelynn can then decide to retry or investigate.

## 2. Launch failure detection — check iTerm session output

If the heartbeat poll fails, check the iTerm session for error indicators. AppleScript can read the session contents:

```python
def _check_session_for_errors(window_id: str) -> Optional[str]:
    """Read recent lines from iTerm session and check for common failure patterns."""
    script = f'''
tell application "iTerm"
    repeat with w in windows
        if id of w = {window_id} then
            set sessionContent to contents of current session of current tab of w
            return last paragraph of sessionContent
        end if
    end repeat
end tell'''
    result = subprocess.run(['osascript', '-e', script], capture_output=True, text=True)
    output = result.stdout.strip()
    error_patterns = ['command not found', 'zsh:', 'Error:', 'ENOENT', 'permission denied']
    for p in error_patterns:
        if p.lower() in output.lower():
            return output
    return None
```

If an error is detected, include it in the return value:

```python
if not confirmed:
    error_output = _check_session_for_errors(window_id)
    if error_output:
        result['status'] = 'launch_failed'
        result['error'] = error_output
```

This gives Evelynn actionable info: "Ornn failed: `zsh: command not found: claude`".

## 3. Heartbeat dashboard — `agent_status` with age display

Enhance `agent_status` (when called without a name) to include a human-readable `heartbeat_age` field:

```python
# In agent_status, for each agent:
if hb:
    age_seconds = (datetime.now(timezone.utc) - datetime.strptime(hb, '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc)).total_seconds()
    if age_seconds < 60:
        heartbeat_age = f'{int(age_seconds)}s ago'
    elif age_seconds < 3600:
        heartbeat_age = f'{int(age_seconds // 60)}m ago'
    else:
        heartbeat_age = f'{int(age_seconds // 3600)}h ago'
else:
    heartbeat_age = 'never'
```

This makes `agent_status()` a quick dashboard — Evelynn sees "bard: 12s ago, ornn: never" instead of parsing raw timestamps.

## 4. Evelynn liveness monitoring — heartbeat watchdog

Evelynn is the hub — if she dies, no one notices until Duong checks manually. Solution: a lightweight cron job that checks Evelynn's heartbeat and alerts Duong via Telegram if she's gone stale.

**Script:** `scripts/evelynn-watchdog.sh`

```bash
#!/bin/bash
# Run via cron every 5 minutes. Alerts Duong on Telegram if Evelynn's heartbeat is stale.
REGISTRY="$(dirname "$0")/../agents/health/registry.json"
BOT_TOKEN=$(cat "$(dirname "$0")/../secrets/telegram-bot-token")
CHAT_ID=$(cat "$(dirname "$0")/../secrets/telegram-chat-id")
STALE_SECONDS=300  # 5 minutes

if ! command -v jq >/dev/null 2>&1; then exit 0; fi

LAST_HB=$(jq -r '.evelynn.last_heartbeat // empty' "$REGISTRY")
if [ -z "$LAST_HB" ]; then
    MSG="⚠️ Evelynn has no heartbeat in the registry. She may not be running."
else
    HB_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$LAST_HB" "+%s" 2>/dev/null || date -d "$LAST_HB" "+%s")
    NOW_EPOCH=$(date -u "+%s")
    AGE=$((NOW_EPOCH - HB_EPOCH))
    if [ "$AGE" -lt "$STALE_SECONDS" ]; then
        exit 0  # She's alive, nothing to do
    fi
    MSG="⚠️ Evelynn's heartbeat is ${AGE}s old (last: ${LAST_HB}). She may be dead or stuck."
fi

# Send Telegram alert
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="$CHAT_ID" -d text="$MSG" > /dev/null
```

**Cron entry:** `*/5 * * * * bash /path/to/strawberry/scripts/evelynn-watchdog.sh`

This runs outside the agent system entirely — it works even when every agent is dead. Duong gets a Telegram message on his phone: "Evelynn's heartbeat is 600s old. She may be dead or stuck."

## 5. Evelynn revival — Telegram command + Mac shortcut

Two paths for Duong to revive Evelynn without opening his laptop:

### A. Telegram `/revive` command

Extend the Telegram bot to handle a `/revive` command. This requires a small always-on process (or a webhook) that listens for Telegram updates independent of Evelynn's session.

**Script:** `scripts/telegram-revive-listener.sh` (run as a launchd daemon)

```bash
#!/bin/bash
# Long-poll Telegram for /revive commands. Launches Evelynn when received.
BOT_TOKEN=$(cat /path/to/secrets/telegram-bot-token)
CHAT_ID=$(cat /path/to/secrets/telegram-chat-id)
OFFSET=0
WORKSPACE="/path/to/strawberry"

while true; do
    RESPONSE=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=30")

    # Process each update
    echo "$RESPONSE" | jq -c '.result[]' | while read -r update; do
        UPDATE_ID=$(echo "$update" | jq '.update_id')
        TEXT=$(echo "$update" | jq -r '.message.text // empty')
        FROM_CHAT=$(echo "$update" | jq -r '.message.chat.id // empty')
        OFFSET=$((UPDATE_ID + 1))

        # Only respond to Duong's chat
        if [ "$FROM_CHAT" != "$CHAT_ID" ]; then continue; fi

        if [ "$TEXT" = "/revive" ]; then
            # Launch Evelynn via AppleScript
            osascript -e 'tell application "iTerm" to activate' \
                      -e "tell application \"iTerm\" to create window with profile \"Evelynn\""
            # Send confirmation
            curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                -d chat_id="$CHAT_ID" -d text="🔄 Launching Evelynn..." > /dev/null
        fi
    done

    sleep 2
done
```

### B. Mac keyboard shortcut (local fallback)

Create an Automator Quick Action or a Raycast script that launches Evelynn in iTerm. Duong can trigger it via a keyboard shortcut (e.g., `Ctrl+Opt+E`).

```bash
# Raycast script or Automator action
cd /path/to/strawberry && osascript -e '
tell application "iTerm"
    activate
    set newWindow to (create window with profile "Evelynn")
    tell current session of current tab of newWindow
        set name to "Evelynn"
        write text "cd /path/to/strawberry && claude --model opus"
    end tell
end tell'
```

This is the local fallback — works when Duong is at his Mac but doesn't require opening Terminal manually.

# Files changed

- `mcps/agent-manager/server.py`:
  - `launch_agent` — add heartbeat polling loop + iTerm error check after launch
  - `agent_status` — add `heartbeat_age` field
  - New helper: `_check_session_for_errors(window_id)`
- `scripts/evelynn-watchdog.sh` — cron-based liveness check, alerts via Telegram
- `scripts/telegram-revive-listener.sh` — long-poll listener for `/revive` command
- LaunchAgent plist for the revive listener daemon

# Risk

Low. The heartbeat poll adds up to 30s to `launch_agent` — but only when the agent fails to start (happy path confirms in ~5-10s). The iTerm content read is a fallback, not a hot path.
