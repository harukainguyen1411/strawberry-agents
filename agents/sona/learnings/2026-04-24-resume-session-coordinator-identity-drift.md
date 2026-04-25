# Learning: Resume-session coordinator identity drift

**Date:** 2026-04-24
**Session:** 576ce828-0eb2-457e-86ac-2864607e9f22 (shard 4df78d45)
**Concern:** work

## What happened

Session `576ce828` resumed after a `/compact` without a "Hey Sona" greeting. CLAUDE.md Caller Routing fired its "no greeting → Evelynn default" rule. I booted as Evelynn and merged PR #37 (universal worktree isolation — Evelynn's infrastructure territory) before Duong caught the mis-routing. This is a recurrence of the April 22 identity-misroute class.

The earlier April 22 instance (shard `0cf7b28e`) produced postmortem `assessments/work/2026-04-22-coordinator-identity-misroute-feedback.md` and mitigation #3 (bash cwd-wedge protocol, `8e796f1`). That mitigation targets a different failure mode (bash env confusion) not the greeting-drop-on-resume failure.

## Root cause

`/compact` discards the conversation prefix, including the original "Hey Sona" greeting. On resume, the coordinator startup read happens without that context. CLAUDE.md Caller Routing falls back to Evelynn. The prior shard content (which correctly identifies the session as Sona/work) is not read before routing fires.

## Impact

- Evelynn-scope infrastructure change (PR #37) landed under a session carrying `[concern: work]` state.
- Misrouted inbox monitor had to be stopped and re-armed.
- No data loss; no work-repo artifacts touched.

## Proposed fix (not implemented)

Before applying CLAUDE.md Caller Routing on session resume, read the most recent `last-sessions/` shard and check the `**Concern:**` field. If it reads `work`, treat this as a Sona session regardless of absent greeting. The greeting rule should only fire on a genuinely new session (no prior shards or shard concern = personal).

## Action items

- Sona: on resume post-compact, explicitly read the last shard before any routing fires. Use shard `**Concern:**` field as identity anchor.
- Evelynn: coordinate on implementing JSONL-greeting-resolution fallback. Full proposal in Evelynn inbox `agents/evelynn/inbox/20260424-0647-013277.md`.
- Longer term: commission Swain or Karma to implement a structural concern-check-on-resume mechanism so the routing rule is grounded in session history, not just greeting text.

## Standing rule

When re-opening a session where no greeting is visible, read `agents/sona/memory/last-sessions/INDEX.md` first and open the most recent shard. If the shard says `Concern: work`, resume as Sona. Do not apply CLAUDE.md Caller Routing until shard concern is confirmed.
