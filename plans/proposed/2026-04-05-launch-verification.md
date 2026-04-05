---
title: Launch verification & heartbeat visibility
status: proposed
owner: bard
created: 2026-04-05
---

# Problem

`launch_agent` returns `"launched"` immediately after creating the iTerm window and sending the startup command. It doesn't verify Claude Code actually started. Today Ornn was launched 5 times — each time the tool reported success, but Claude crashed immediately (likely a zsh error). No feedback reached the caller.

# Solution

Three improvements, ordered by impact:

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

# Files changed

- `mcps/agent-manager/server.py`:
  - `launch_agent` — add heartbeat polling loop + iTerm error check after launch
  - `agent_status` — add `heartbeat_age` field
  - New helper: `_check_session_for_errors(window_id)`

# Risk

Low. The heartbeat poll adds up to 30s to `launch_agent` — but only when the agent fails to start (happy path confirms in ~5-10s). The iTerm content read is a fallback, not a hot path.
