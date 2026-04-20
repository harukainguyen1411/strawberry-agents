# Compact Workflow — Lissandra + PreCompact Hook

> Source of truth: `plans/in-progress/personal/2026-04-20-lissandra-precompact-consolidator.md`

## Overview

`/compact` is a context-management operation, not a session boundary. Running it without first running `/end-session` discards the durable artifacts that session produces — handoff shards, journal entries, learnings, commits. Duong frequently runs `/compact` mid-session and never wants to close the session at that point, so a compact-specific consolidation path is needed.

## Solution

Three components work together:

1. **Lissandra** — a Sonnet-medium single-lane agent (`memory-consolidator` role slot). She mirrors the coordinator's `/end-session` close protocol (minus the full transcript archive) and writes all artifacts in the coordinator's voice, not her own.
2. **`scripts/hooks/pre-compact-gate.sh`** — a PreCompact hook script that blocks a bare `/compact` and prompts the coordinator to run `/pre-compact-save` first.
3. **`/pre-compact-save` skill** (`.claude/skills/pre-compact-save/SKILL.md`) — the primary entry point. Detects the active coordinator, spawns Lissandra via the Agent tool, then verifies the sentinel and commit on return.

## Flow (§3.1.1 of the plan)

```
1. Duong types /compact in a coordinator session.
2. PreCompact hook fires (matcher: "manual").
3. Hook checks .no-precompact-save at repo root → if present, allow (exit 0).
4. Hook checks /tmp/claude-precompact-saved-<session_id> sentinel → if present, allow + remove sentinel (exit 0).
5. Neither present → hook emits {"decision":"block","reason":"Run /pre-compact-save first..."}.
6. Duong (or coordinator) runs /pre-compact-save.
   - Skill detects coordinator (Evelynn or Sona) from session context.
   - Skill spawns Lissandra with session_id, transcript_path, coordinator.
   - Lissandra writes: handoff shard, session shard, journal entry, learnings (if warranted), commit.
   - Lissandra touches /tmp/claude-precompact-saved-<session_id>.
7. Duong re-runs /compact. Hook sees sentinel → allows compact, cleans up sentinel.
```

Auto-compact (`compaction_trigger: "auto"`) is never blocked — the hook registers `"matcher": "manual"` only.

## Coordinator Impersonation

Lissandra writes all artifacts to `agents/<coordinator>/...`, never to `agents/lissandra/`. Journal entries are first-person in the coordinator's voice, signed with `--- consolidated by Lissandra (pre-compact) ---` for provenance. Artifacts written per consolidation:

| Artifact | Path |
|----------|------|
| Handoff shard | `agents/<coordinator>/memory/last-sessions/<short-uuid>.md` |
| Session shard | `agents/<coordinator>/memory/sessions/<short-uuid>.md` |
| Journal entry | `agents/<coordinator>/journal/cli-YYYY-MM-DD.md` (appended) |
| Learnings | `agents/<coordinator>/learnings/YYYY-MM-DD-<topic>.md` (conditional) |
| Transcript excerpt | Deferred to phase 2 (`clean-jsonl.py --since-last-compact`) |
| Commit | `chore: lissandra pre-compact consolidation for <coordinator> — ...` |

Lissandra never calls `/end-session` on the coordinator's behalf — that skill is `disable-model-invocation: true` and remains human-triggered.

## Sentinel Mechanics

- **Completion sentinel:** `/tmp/claude-precompact-saved-<session_id>` — touched by Lissandra at end of her run; consumed and removed by the hook on next `/compact`.
- **Opt-out sentinel:** `.no-precompact-save` at repo root — if present, the hook always allows `/compact` without prompting. Remove it to re-enable the gate.

## Scope Boundary

Coordinator sessions only (Evelynn, Sona). Subagent sessions are out of scope — subagents already have `/end-subagent-session` and their state does not survive compact in isolation.

## Related Files

| File | Purpose |
|------|---------|
| `.claude/agents/lissandra.md` | Lissandra agent definition (frontmatter + protocol body) |
| `.claude/skills/pre-compact-save/SKILL.md` | `/pre-compact-save` skill — primary entry point |
| `scripts/hooks/pre-compact-gate.sh` | PreCompact hook script — block-and-prompt logic |
| `.claude/settings.json` | PreCompact hook registration (`"matcher": "manual"`) |
| `agents/lissandra/profile.md` | Lissandra agent profile |
