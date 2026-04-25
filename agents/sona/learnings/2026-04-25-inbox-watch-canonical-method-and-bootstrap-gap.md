# Inbox-watch canonical method and bootstrap startup-chain gap

**Date:** 2026-04-25
**Session:** c1463e58 (f993d23d, hands-off normal track)
**Severity:** low-medium — operational correctness; silent failure mode

## The fact

Canonical inbox monitor invocation for Sona is:
```
CLAUDE_AGENT_NAME=sona bash scripts/hooks/inbox-watch.sh
```

The `inbox-watch-bootstrap.sh` SessionStart hook is designed to nudge Sona to arm this as her first act. This is NOT automatic — it only nudges; Sona must execute.

## The gap

`inbox-watch-bootstrap.sh` silently no-ops when `CLAUDE_AGENT_NAME` is not set in the launcher environment at the time the hook fires. The nudge message still appears in context, but the actual watch script cannot self-arm (it needs the identity to filter inbox correctly). Result: the nudge fires, Sona reads it, but without the env var the bootstrap cannot auto-arm the watch.

## What went wrong this session

I hand-rolled a poller using Bash + Monitor tool with a custom script instead of calling the canonical script. This is wrong for two reasons:
1. The hand-rolled version is unstable — no canonical contract, no filtering logic.
2. It masks the bootstrap gap rather than surfacing it.

## Correct pattern

1. On every session start: first act is `CLAUDE_AGENT_NAME=sona bash scripts/hooks/inbox-watch.sh`.
2. If the bootstrap hook fires the nudge, execute the above line immediately.
3. Never hand-roll a poller — always use the canonical script.

## Fix needed (Evelynn / Karma lane)

Launcher should export `CLAUDE_AGENT_NAME=sona` before invoking `inbox-watch-bootstrap.sh`, or the bootstrap hook should infer identity from session context (e.g. by reading the coordinator greeting from early transcript lines).

## Cross-pointers

- `scripts/hooks/inbox-watch.sh` — canonical script
- `scripts/hooks/inbox-watch-bootstrap.sh` — SessionStart nudge hook
- `agents/sona/memory/open-threads.md` — "Inbox-watch startup-chain gap" thread
