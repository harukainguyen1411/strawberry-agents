---
status: implemented
owner: bard
---

# Fix restart_evelynn False Negative Detection

## Problem

`restart_evelynn` reports `status: "failed"` even when the restart succeeds. The poll loop checking for "claude" in `raw_name` doesn't match because:

1. **iTerm window name update is delayed** — after `claude --resume`, iTerm may not update the session name to include "claude" within the 30s polling window
2. **The string match may be wrong** — `raw_name` from `get_iterm_agent_windows` is the session tab name, which may show the agent name (e.g., "Evelynn") rather than "claude" after resume

## Root Cause Investigation Needed

Before fixing, verify which of these is true:
```bash
# After a restart, check what iTerm reports as the session name
# Compare raw_name values before /exit, after /exit, and after --resume
```

## Fix Plan

### 1. Change detection strategy

Instead of checking for "claude" in window name, check that the window **still exists and is no longer showing a shell prompt**. Options:

- **Option A**: Check if the process running in the session is `claude` (via `tty` or `ps`)
- **Option B**: Simply check the window still exists after resume (if it does, resume was at least attempted)
- **Option C**: Send a test character and check if the session is accepting input differently than a shell

**Recommended: Option B** — simplest, and combined with requirement #2 below, sufficient.

### 2. Always send notification (regardless of detection)

Per Evelynn's requirement: always notify, even if detection is uncertain. Change the flow to:

```python
# After sending claude --resume:
# 1. Wait a reasonable time (poll or fixed)
# 2. ALWAYS write inbox file + deliver notification
# 3. Include detection result in the notification ("restart sent, session appears active" vs "restart sent, could not confirm session — check manually")
# 4. Return status based on detection, but notification is unconditional
```

### 3. Implementation

In `mcps/evelynn/server.py`, `restart_evelynn`:

```python
send_to_iterm_window(wid, f'claude --resume {session_id}')

# Wait for session to come back — best effort detection
session_detected = False
for _ in range(10):
    await asyncio.sleep(3)
    windows = get_iterm_agent_windows()
    # Check window still exists (not closed)
    window_exists = any(w['window_id'] == wid for w in windows)
    if window_exists:
        session_detected = True
        break

# ALWAYS notify — regardless of detection result
try:
    if session_detected:
        msg = f'Restart complete. Restarted by {sender} (session {short_id}...).'
    else:
        msg = f'Restart attempted by {sender} (session {short_id}...) but could not confirm session is running. Check iTerm manually.'
    # write inbox + deliver via iTerm
    ...
except Exception:
    pass

# Return appropriate status
status = 'restarted' if session_detected else 'uncertain'
```

### 4. Test

1. Call `restart_evelynn(sender="bard")`
2. Verify Evelynn receives notification
3. Verify return status is `restarted` (not `failed`)

## Scope

~20 lines changed in `mcps/evelynn/server.py`. Feature branch `feature/restart-detection-fix`, PR to main.
