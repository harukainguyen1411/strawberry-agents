---
name: check-inbox
description: Scan the current coordinator's inbox for pending messages, display them, archive each to inbox/archive/YYYY-MM/ with status read and read_at timestamp. Companion skill to the inbox-watch Monitor watcher.
disable-model-invocation: false
allowed-tools: Bash Read Write Edit Glob Grep
---

# /check-inbox — read and archive pending inbox messages

Implements plans/in-progress/2026-04-20-strawberry-inbox-channel.md §3.4.

## Purpose

Scan `agents/<AGENT>/inbox/` for files with `status: pending`, display each
message, **archive** them to `agents/<AGENT>/inbox/archive/<YYYY-MM>/` with
`status: read` and a `read_at` timestamp. Enforces the pending-only invariant
of the main inbox directory.

After running, `agents/<AGENT>/inbox/` contains zero `status: pending` files.

## Step 0 — Identify the coordinator

Resolve agent name in this order:

1. `CLAUDE_AGENT_NAME` environment variable (set by `claude --agent <name>`)
2. `STRAWBERRY_AGENT` environment variable
3. `.claude/settings.json` `.agent` field (case-insensitive)

If none of the above resolves a name, refuse:

```
check-inbox: cannot identify agent — set CLAUDE_AGENT_NAME or STRAWBERRY_AGENT
```

## Step 1 — List pending messages

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
ls "$REPO_ROOT/agents/<AGENT>/inbox/"*.md 2>/dev/null || echo "(no .md files)"
```

For each `.md` file found at the top level of `inbox/` (not in `archive/`
subdirectories), read its frontmatter and collect those with `status: pending`.

If none are pending, print:

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

## Step 3 — Archive each message

For each pending message, perform the following steps **in order** (the
ordering is critical for watcher filter discipline — write `status: read`
before the `mv` so a concurrent watcher event sees the file already read):

### Step 3a — Rewrite frontmatter in place

Use the Edit tool:

- Change `status: pending` → `status: read`
- Add a new line `read_at: <ISO-8601 UTC timestamp>` directly after the
  `status: read` line.

Use `date -u +%Y-%m-%dT%H:%M:%SZ` via Bash for the timestamp.

Do not remove any other frontmatter fields. Do not alter the body text.

Example of updated frontmatter:

```yaml
---
from: sona
to: evelynn
priority: normal
timestamp: 2026-04-21T14:02:00Z
status: read
read_at: 2026-04-21T14:05:33Z
---
```

### Step 3b — Compute the archive path

- Derive `<YYYY-MM>` from the file's `timestamp:` frontmatter field.
  - Parse the first 7 characters (e.g. `2026-04` from `2026-04-21T14:02:00Z`).
  - Fallback: if `timestamp:` is absent, use the file's mtime:
    `date -r <file> +%Y-%m 2>/dev/null || date +%Y-%m`
- Archive path: `agents/<AGENT>/inbox/archive/<YYYY-MM>/<original-filename>`

### Step 3c — Move the file

```bash
mkdir -p "agents/<AGENT>/inbox/archive/<YYYY-MM>"
mv "agents/<AGENT>/inbox/<filename>" "agents/<AGENT>/inbox/archive/<YYYY-MM>/<filename>"
```

**Concurrency guard:** if the `mv` fails because the source file is already
gone (rare — would require two parallel `/check-inbox` runs on the same inbox),
skip and continue. Do not abort. This is idempotent by design.

## Step 4 — Summary

After processing all pending messages, print a one-line summary:

```
check-inbox: archived <N> message(s) for <AGENT>.
```

Post-condition: `agents/<AGENT>/inbox/` contains zero `status: pending` files.
The `archive/` subdirectory is the only remaining populated location.

## Refusal rules

- If the agent directory `agents/<AGENT>/` does not exist, refuse:
  `check-inbox: unknown agent <name>`
- If `agents/<AGENT>/inbox/` does not exist, print:
  `check-inbox: inbox directory not found for <AGENT> — no messages`
  and exit 0 (not an error; the inbox may never have been written to).
- Never write secrets into any message body.
- Never modify any field other than `status` and adding `read_at`.
- Never write to `archive/` from the `send` path — the `send` path in
  `/agent-ops` always writes to the flat `inbox/` directory only.
