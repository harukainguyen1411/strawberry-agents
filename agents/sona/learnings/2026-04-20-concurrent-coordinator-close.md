# Concurrent coordinator close races on shared state

**Date:** 2026-04-20
**Context:** Both Sona and Evelynn were running `/end-session` in parallel. Noticed: Sona's staged transcript (`agents/sona/transcripts/2026-04-20-002efe6a.md`) got swept up into Senna's unrelated state-update commit (`8ccb86c`), because Senna's `git add` pulled staged-but-not-committed files from the index. Separately, the `remember:remember` skill writes to `.remember/` — shared across coordinators — which would race if both invoked.

## Lesson

Shared working tree + multiple concurrent coordinators/subagents = staging collisions. Anything left staged but not committed can be swept up by the next agent's `git add`.

## Rules of thumb

1. **Never leave work staged across agent turns.** Commit immediately after `git add`. Don't batch-stage across multiple Edit/Write operations if subagents might race.
2. **Use agent-specific paths for handoff state.** Sona's `memory/last-sessions/<uuid>.md` + journal at `agents/sona/journal/` are Sona-only. No collision with Evelynn's `agents/evelynn/...`.
3. **Avoid `remember:remember` when a second coordinator is closing.** The skill writes to `.remember/remember.md` (shared). Evelynn has already established a bypass (writes shards to `memory/last-sessions/` instead — see `plans/approved/2026-04-18-evelynn-memory-sharding.md` §D6). Sona should adopt the same pattern until the remember plugin is made agent-scoped.
4. **When a parallel coordinator is mid-close, don't run pre-commit-heavy staging sequences.** The pre-commit hooks read the full working tree and can surface unrelated files the other agent is mid-edit on.

## When this matters

Mostly irrelevant in day-to-day — one coordinator at a time. Bites on session-end hand-overs, PreCompact flushes, and any time Duong is running Evelynn + Sona concurrently from different terminals.

## Fallback protocol

If mid-close and suspect collision:
- `git status --short` before each stage step.
- Stage by explicit path, never `git add .` or `git add -A`.
- Check `git log --oneline -5` before final commit to confirm no one else pushed.
