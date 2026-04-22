# PR #32 — Firestore config-leak fix plan-fidelity

## Verdict

APPROVE. Plan `2026-04-22-firestore-session-config-leak-fix.md` honored task-by-task (T1–T7 all land; T8 correctly deferred to post-deploy).

## Reviewer-auth state

`missmp/company-os` is not accessible to `strawberry-reviewers` account (same gap recorded in `2026-04-21-pr57-company-os-reviewer-access-gap.md` and `2026-04-21-pr59-...`). S27+ still broken. Verdict written to `/tmp/lucian-pr-32-verdict.md` per task spec; Duong / Senna post.

## Fidelity highlights

- T1 xfail commit (`cc34cb3`) precedes impl (`12b9fd7`) on same branch — Rule 12 satisfied
- All 4 xfail assertions carry plan filename in reason string (strict)
- T3 hardcode `version = 2` at main.py L2175 — exact location called out in plan L128
- T4 parallel S2 fetch via `ThreadPoolExecutor(max_workers=min(len, 10))` + graceful `{}` on exception — mirrors `dashboard_sessions` pattern as plan specified

## Drift noted

- T6 removed entire `config: {...}` fixture key (plan L161 only listed `configVersion`/`factoryVersion`). Broader strip is correct (otherwise invariant broken) but logged as DR-1 scope-text audit.
- DR-2: S2 persistence open question goes live on merge+wipe; ensure follow-up plan exists before T7 go-ahead or accept dangling-FK window consciously.

## Pattern — commit-message fidelity rebound

Commit body of `12b9fd7` matches diff this time. Contrast with `45702a8` drift recorded in `2026-04-22-pr32-hotfix-rereview.md`. Reading actual diff alongside commit body remains the right check.
