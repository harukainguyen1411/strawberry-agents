# 2026-04-20 — session-state-encapsulation decomposition

## Context

Azir ADR `plans/2026-04-20-session-state-encapsulation.md` on `company-os` repo branch `feat/demo-studio-v3` (head `d68df34`). ADR introduces `session_store.py` as the sole Firestore boundary on Service 1 + migrates `SessionStatus` enum. Sequenced ahead of the two sibling managed-agent ADRs on the same branch because both depend on its `transition_status` + terminal-status set.

Output: `plans/2026-04-20-session-state-encapsulation-tasks.md` (commit `ea17448`, pushed).

## Key structural decisions

- **Phase-scoped task IDs `SE.<phase>.<n>`** (SE.0 preflight, SE.A new module, SE.B migration, SE.C enum backfill, SE.D TTL cache, SE.E grep gate, SE.F HTTP follow-ups). Matches Azir's §6 phase structure one-to-one; easier to cross-reference in PR descriptions.
- **TDD pairing = one xfail commit per impl commit** where the impl changes production code. Test-only refactors (SE.B.6 mock-target renames) are exempt per universal invariant 12 ("changes only test harness, not impl"). Documented that exemption inline rather than leaving reviewer to infer.
- **Hard serial point called out explicitly** between SE.C.3 (live `--apply` enum backfill) and SE.B.8 (delete `approved` route + remove legacy-enum code-branches). Wrong order orphans every pre-migration row. This is the single riskiest ordering call in the plan; flagged in two places — the task body and the dispatch plan — for redundancy.
- **Follow-up HTTP-spec work lifted into a separate `SE.F` band** rather than interleaved. ADR §6 explicitly calls this "outside the extraction PRs"; keeping it separate preserves the mergeable-per-phase property.

## Cross-ADR coupling surfaced

Both sibling ADRs (`managed-agent-lifecycle`, `managed-agent-dashboard-tab`) consume:
1. `session_store.transition_status` as a call path
2. Terminal-status set `{completed, cancelled, qc_failed, build_failed, built}` from §4.3

→ Their implementation cannot start before SE.A.6 (transition_status live) AND SE.C.3 (backfill done). I flagged this in the dispatch plan as a Sona-level sequencing gate. If Sona runs all three ADRs' task breakdowns in parallel, she needs this dependency surfaced — the individual task IDs in this ADR's breakdown don't appear in the sibling ADRs.

## Non-obvious things I noticed during breakdown

- `main.py:1473` — there's a dead-looking field `"archived": status == "archived"` in the status response. My SE.B.8 task calls it out for removal/rename, but I left the decision to the impl agent (might still be consumed by the Studio UI). Flagged in the acceptance criteria.
- `phase.py:27` calls `main.update_session_field` — not `session.update_session_field`. So the call-site audit must catch indirections through `main` re-exports, not just direct `from session import` patterns. SE.B.5 names this explicitly.
- `tests/test_preview.py` has two patch patterns: `session.get_db` (old style) AND `main.update_session_status` (re-export style). SE.B.6 enumerates both. Missed either and the pre-push hook fails.
- Test file count for mock-target rename: 15 files (ADR said "~15"; my grep confirmed). `tests/test_sse_server_l1.py` alone has 15 occurrences of `session.get_db`.

## Open questions I surfaced for Duong

Five OQs (OQ-SE-1 through OQ-SE-5). Most are lightweight (pagination style, healthcheck semantics); the single operationally important one is **OQ-SE-1 "unknown legacy status during backfill"** — ADR §4.2 mapping table is closed, but real Firestore may have stray values. My suggested default is `cancelled + cancelReason: unknown_legacy_status`; needs Duong confirmation before SE.C.1 impl runs.

## Estimate gap vs ADR

ADR §6 rolls up to ~4.5 hours. My decomposition rolls up to ~16 person-hours. Delta is:
- 14 xfail test commits (TDD gate was not modelled in ADR §6 estimates)
- Per-file call-site PRs for review bandwidth (ADR bundles as "Phase B, 2-3h including tests")
- SE.0 preflight (audit + index check) not in ADR §6

I noted the delta in the task file's Estimates table so Sona doesn't think I'm inflating.

## Process notes for next time

- Company-os repo does NOT have `scripts/safe-checkout.sh` (that script lives only in strawberry-agents). Work-concern branch switches go via raw `git worktree add` — added a worktree at `~/Documents/Work/mmp/workspace/company-os-demo-studio-v3` to read the ADR without disturbing the existing `chore/tdd-gate-clean` checkout. Leave the worktree in place; it's cheap and useful for subsequent Kayn calls on the same branch.
- The `tdd-gate.yml` workflow exists on `chore/tdd-gate-clean` (commit `0a154c0`) but NOT YET on `feat/demo-studio-v3`. Tasks in this plan reference the gate as active. If `chore/tdd-gate-clean` doesn't merge to main before builders start SE.A.1, the xfail-first discipline is honour-system only. Flag to Sona if she schedules SE.A.1 before the gate PR lands.
- Task-file frontmatter convention on this repo: `status: draft` / `owner: Sona` (ADR author convention). For task files I used `owner: Kayn` (the task-breakdown author) + `plan:` field pointing back to the ADR. No existing task files to precedent against — ADR author confirmed this is the first decomposition in this plans/ subtree.
