---
name: check-inbox
description: Scan the current coordinator's inbox for pending messages, display them, and mark each as read. Auto-invoked when the strawberry-inbox channel fires a new-message event.
disable-model-invocation: false
allowed-tools: Bash Read Write Edit Glob Grep
---

# /check-inbox — read and mark pending inbox messages

## Purpose

Scan `agents/<AGENT>/inbox/` for files with `status: pending`, display each
message, flip `status` to `read`, and add a `read_at` timestamp. This is the
companion skill to the `strawberry-inbox` channel plugin.

## Step 0 — Identify the coordinator

Resolve agent name in this order:
1. `CLAUDE_AGENT_NAME` environment variable (set by `claude --agent <name>`)
2. `STRAWBERRY_AGENT` environment variable
3. `$ARGUMENTS` if provided (e.g. `/check-inbox evelynn`)

If none of the above resolves a name, refuse:
```
check-inbox: cannot identify agent — set STRAWBERRY_AGENT or pass agent name as argument
```

## Step 1 — List pending messages

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
ls "$REPO_ROOT/agents/<AGENT>/inbox/"*.md 2>/dev/null || echo "(no .md files)"
```

For each `.md` file found, read its frontmatter and collect those with
`status: pending`. If none are pending, print:

```
No pending messages for <AGENT>.
```

...and stop (exit 0).

## Step 2 — Display each pending message

For each pending message file, print a formatted block:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
From:      <from>
Priority:  <priority>
Timestamp: <timestamp>
File:      agents/<agent>/inbox/<filename>
──────────────────────────────────────────────────
<body text — everything after the closing --- frontmatter fence>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Step 3 — Mark each message as read

For each pending message, update its frontmatter in place using the Edit tool:

- Change `status: pending` → `status: read`
- Add a new line `read_at: <ISO-8601 UTC timestamp>` directly after the
  `status: read` line (use `date -u +%Y-%m-%dT%H:%M:%SZ` via Bash for the timestamp)

Do not remove any other frontmatter fields. Do not alter the body text.

Example of updated frontmatter:
```yaml
---
from: sona
to: evelynn
priority: normal
timestamp: 2026-04-20 14:02
status: read
read_at: 2026-04-20T14:05:33Z
---
```

## Step 4 — Summary

After processing all pending messages, print a one-line summary:

```
check-inbox: marked <N> message(s) as read for <AGENT>.
```

## Refusal rules

- If the agent directory `agents/<AGENT>/` does not exist, refuse:
  `check-inbox: unknown agent <name>`
- If `agents/<AGENT>/inbox/` does not exist, print:
  `check-inbox: inbox directory not found for <AGENT> — no messages`
  and exit 0 (not an error; the inbox may never have been written to).
- Never write secrets into any message body.
- Never modify any field other than `status` and adding `read_at`.
