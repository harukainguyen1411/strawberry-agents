# Kayn — Tests Dashboard task breakdown

**Date:** 2026-04-19
**Output:** `plans/proposed/2026-04-19-tests-dashboard-tasks.md` (commit 1007c8e)
**Source ADR:** `plans/approved/2026-04-19-tests-dashboard.md` (Azir, e97828d; amended with Playwright D4b)

## Shape of the breakdown

Seven primary tasks + two ADR-tracked follow-ups + one hygiene +
one optional hygiene sub-task:

- TD.H1 — gitignore edits in both repos (no xfail, hygiene)
- TD.H1b — pre-commit path-block hook (optional, gated on Duong)
- TD.1 — Vitest reporter package (xfail-first)
- TD.1b — Playwright reporter package (xfail-first)
- TD.1c — pytest plugin patch (CONDITIONAL on DTD-3; stub or real)
- TD.2 — aggregator `build.sh` + shared JSON schema + validation tests (xfail-first)
- TD.3 — static SPA + `dashboards/_shared/tokens.css` + Playwright smoke (xfail-first)
- TD.F1 — rename existing session-dashboard ADR in place
- TD.F2 — amend approved usage-dashboard plan to depend on shared tokens

## Critical path

`TD.H1 → (TD.1 ∥ TD.1b ∥ TD.1c) → TD.2 → TD.3`

TD.F1, TD.F2, TD.H1b parallelize with everything.

## Key decisions

- **Split "Task-1c (pytest plugin)" into conditional stub-vs-real** —
  ADR handoff §Task-4 originally framed it as a two-line additive patch
  to the demo-studio-v3 plugin, but demo-studio-v3 is out of Strawberry
  scope. Called this out as DTD-3 (Duong blocker) with explicit stub
  fallback that just reserves `pytest` in the schema enum.
- **Promoted gitignore to its own TD.H1 task** — Orianna-flagged risk
  from the ADR §Risks section. Separated the defense-in-depth hook as
  optional TD.H1b gated on Duong's call.
- **Promoted ADR follow-ups to explicit tasks TD.F1 / TD.F2** — the ADR
  Decision table rows 6 and 10 both implied follow-up work but did not
  spec them. Called out the Rule 7 nuance: `plan-promote.sh` does not
  cover in-place renames within `approved/`; raw `git mv` is OK there.
- **Schema-location OQ-A flagged in TD.2** — writers live in
  strawberry-app, canonical schema lives in strawberry-agents. Two
  options (vendor copy per writer, or cross-repo relative path). Default
  recommendation: vendor + byte-compare CI check. Flagged for PR review.
- **TD.3 includes creating `dashboards/_shared/tokens.css`** — ADR D6
  says "create up front and amend usage-dashboard to depend on it."
  Bundled the tokens creation into the SPA task (same PR, same
  reviewer) rather than splitting it.
- **UI-PR Rule 16 flagged on TD.3** — QA Playwright run + screenshots +
  report in `assessments/qa-reports/` is a separate gate from the
  smoke test the task owner writes. Called it out in the task body so
  the executor doesn't get blindsided at PR time.

## Duong-blockers enumerated

- DTD-1 — Vitest major pin stability (TD.1)
- DTD-2 — Playwright major pin stability (TD.1b)
- DTD-3 — is any pytest entering either repo? (TD.1c stub-vs-real)
- DTD-4 — aggregator-home split (script in strawberry-agents,
  static files in strawberry-app) — already resolved in ADR but
  flagged for implementer sanity
- DTD-5 — repo scope reminder (informational)

## xfail-first commit specs

Every implementation task (TD.1, TD.1b, TD.1c non-stub, TD.2, TD.3,
TD.H1b) lists its xfail-first test file path, content sketch, commit
message body format (`Refs plan: tests-dashboard, task TD.<n>`), and
initial-fail reason. TD.H1, TD.F1, TD.F2, TD.1c-stub path: no xfail
(Rule 12 scope is TDD-enabled services only).

## Conventions reused

- Task ID prefix `TD.<n>` + sub-letters (H1, H1b, 1, 1b, 1c, F1, F2).
- Per-task fields: Home repo / Goal / Inputs / Outputs / xfail-first
  commit / Acceptance / Prereqs / Parallelizable with.
- Dispatch order section + out-of-scope confirmations section + ADR
  traceability table + commit-prefix guidance section (the commit-
  prefix section is new this session — the Rule-5 ambiguity around
  strawberry-app packages not under `apps/myapps/**` warranted an
  explicit call-out for implementers).

## What I would do differently next time

- The schema-location question (OQ-A in TD.2) could have been
  pre-resolved with Evelynn rather than flagged to the TD.2 implementer.
  Cross-repo file-of-truth coupling is a recurring pattern; a team-
  level default ("always vendor + byte-compare") would save
  per-task debate.
- Did not explicitly version the shared JSON schema (e.g., `schemaVersion:
  1` top-level field). Forward-additive-only per ADR D3 means it won't
  drift hard, but a version stamp would make future evolution cleaner.
  Flag for a future amendment if TD.2 implementer spots the gap.
