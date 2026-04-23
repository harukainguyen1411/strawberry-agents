# Sona inbox monitor not firing on send.sh writes

**Date:** 2026-04-23
**Status:** open — investigate tomorrow
**Severity:** medium (breaks real-time cross-coordinator comms; inbox still reads correctly at startup/check-inbox)

## Symptom

Messages written to `agents/sona/inbox/<timestamp>-<nonce>.md` via `bash scripts/agent-ops/send.sh sona evelynn "<body>"` land on disk correctly (verified file exists, frontmatter valid, archive flow works on next `/check-inbox`) — but the **live monitor in Sona's running terminal does not surface them**. Duong observed this twice today:

- Around 1154 UTC — self-compact research findings to Sona (`agents/sona/inbox/20260423-1154-945298.md`)
- Around 1444 UTC — rule-rewrite directive to Sona (`agents/sona/inbox/20260423-1444-955445.md`)

And Duong noted "same bug happens earlier" — implying at least one prior occurrence before today's first documented instance.

## What's expected

Some watcher (FS event-based? polling-based?) should detect new files under `agents/<coordinator>/inbox/*.md` with `status: pending` and emit a notification into the coordinator's active terminal session so the running coordinator sees the message without having to invoke `/check-inbox` manually.

## What's actually happening

Files land; monitor silent. Sona would only see the messages on her next:
- Session boot (reads `/check-inbox` as part of startup)
- Manual `/check-inbox` invocation mid-session

## Hypotheses to investigate tomorrow

1. **Monitor is not implemented yet** — possible the real-time monitor is a future feature from the inbox-channel plan (`plans/implemented/2026-04-20-strawberry-inbox-channel.md`) that hasn't shipped. Check plan DoD vs actual state.
2. **Monitor watches via Write tool, not Bash writes** — if the watcher hooks into `PostToolUse Write|Edit` it would miss `bash send.sh` writes entirely. This is structurally the same shape as the inbox-write-guard which we explicitly bypass via send.sh. Fix: either the monitor hooks `SessionStart` + FS poll, or it hooks the send.sh script itself.
3. **Monitor listens on wrong path** — might be watching `.remember/now.md` or some legacy location instead of `agents/<coordinator>/inbox/`.
4. **Monitor process not running** — maybe requires a daemon that wasn't started, or a hook that was removed.

## First investigative step for tomorrow

Check `architecture/inbox-channel.md` (or equivalent) for the monitor design. Then grep for any watcher/monitor script under `scripts/` that references `inbox/`. Confirm whether it's FS-event-based (fswatch/inotify) or polling, and how it surfaces notifications into the terminal.

## Related

- `plans/implemented/2026-04-20-strawberry-inbox-channel.md` — original inbox-channel plan
- `plans/implemented/personal/2026-04-23-inbox-write-guard.md` — guard plan (establishes send.sh bypass pattern that might also skip the monitor)
- `scripts/agent-ops/send.sh` — current write path
- `.claude/skills/check-inbox/SKILL.md` — pull-based read path (works correctly)

## Action for tomorrow

Re-open this thread. Dispatch Explore to map the monitor architecture, then decide between (a) fix the monitor to also observe bash-script writes, (b) amend send.sh to emit the notification itself, or (c) accept pull-only and remove any stale "real-time monitor" promise from docs.
