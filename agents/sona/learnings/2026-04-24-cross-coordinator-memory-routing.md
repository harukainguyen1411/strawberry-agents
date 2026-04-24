# Cross-coordinator memory routing — Evelynn owns duong.md edits, Sona routes via inbox

**Date:** 2026-04-24
**Severity:** medium
**last_used:** 2026-04-24

## What happened

Duong requested a new briefing-verbosity rule to be added to `agents/memory/duong.md`. Sona attempted to write the rule directly. Duong rejected this: "tell Evelynn to do it, it's her job." The edit was routed via `/agent-ops send` to Evelynn's inbox (20260424-1125-029953.md).

## The rule

**`agents/memory/duong.md` edits belong to Evelynn's lane.** Even when Sona identifies the need, Sona cannot self-edit cross-coordinator memory.

The correct workflow:
1. Sona identifies the needed change.
2. Sona authors the proposal (the exact text to add, the section to add it to, the rationale).
3. Sona routes via `/agent-ops send` to Evelynn's inbox.
4. Evelynn executes the edit in her own session.

## Scope boundary

The boundary is not Sona's *capability* to edit the file — she can physically write it. The boundary is *ownership*. `agents/memory/duong.md` is system-configuration: it shapes how both coordinators behave across sessions. Evelynn owns that surface. Sona owns her own memory (`agents/sona/memory/`, `agents/sona/learnings/`, etc.) and her own CLAUDE.md.

Analogously: Sona does not edit Evelynn's own memory files, learnings, or journal. Evelynn does not edit Sona's. Cross-cuts go via inbox.

## Exception

If Duong explicitly directs Sona to edit a cross-coordinator file in the same turn ("Sona, update duong.md now"), that's an explicit override and Sona may act. Duong's correction here established the default for cases without explicit override.
