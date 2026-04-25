---
status: approved
concern: personal
owner: karma
created: 2026-04-25
tests_required: true
complexity: quick
orianna_gate_version: 2
tags: [hooks, sessionstart, inbox-watch, deliberation-primitive, idempotence]
related:
  - scripts/hooks/inbox-watch-bootstrap.sh
  - scripts/hooks/sessionstart-coordinator-identity.sh
  - scripts/hooks/tests/inbox-watch-test.sh
  - agents/evelynn/inbox/20260425-0729-102180.md
architecture_impact: none
---

# Watcher-arm directive — source-gate + verify-then-arm rewrite

## Context

`scripts/hooks/inbox-watch-bootstrap.sh` is the SessionStart hook that injects the "FIRST ACTION REQUIRED: invoke the Monitor tool now with command: `bash scripts/hooks/inbox-watch.sh` … Arm it before doing anything else." directive into coordinator sessions. Today it emits on `source ∈ {startup, resume, clear, compact}` (script lines 39–42, 98). On a `/compact` continuation the prior Monitor watcher task persists across the compact boundary, so a coordinator that complies literally with the directive spawns a duplicate `inbox-watch.sh` process. Sona caught one such duplicate on session `c1463e58` post-`/compact` (`agents/evelynn/inbox/20260425-0729-102180.md`); Evelynn likely produced the same on her own earlier compact this session.

This is the same shape as the deliberation-primitive failure mode shipped in PR #49: **literal directive vs. goal**. The directive's literal form ("arm it") and the directive's goal ("have a watcher armed") diverge whenever the goal is already satisfied — exactly what happens on `resume|clear|compact` where prior Monitor state persists. The hook fires before the first turn, so no intent-block runs to catch the divergence. Sona's recommended combined fix is structural elimination on the resume path (source gate) plus prompt-side hardening (verify-then-arm wording) so the goal is explicit on any remaining surface.

Sona's note suggested the directive lives in `sessionstart-coordinator-identity.sh`; verification places it in `inbox-watch-bootstrap.sh:98`. The coordinator-identity hook does not emit any watcher directive — it only emits the FRESH/RESUMED session sentinel. Both fixes target `inbox-watch-bootstrap.sh` only.

## Decision

1. **Source gate (structural)** — Restrict directive emission to `source=startup`. The `case` block at `inbox-watch-bootstrap.sh:39–42` currently allowlists `startup|resume|clear|compact`; narrow it to `startup` only. On `resume|clear|compact` the hook exits silently. Rationale: a /compact continuation always inherits the prior session's running Monitor task — a fresh directive is at best redundant and at worst spawns a duplicate process.

2. **Verify-then-arm prompt rewrite (defense-in-depth)** — Replace the literal-arming wording with a goal-explicit form: "Verify a watcher is armed for `${display_name}` (check existing Monitor tasks plus `ps aux | grep inbox-watch.sh` matched against your `CLAUDE_AGENT_NAME`). If absent, invoke Monitor with `bash scripts/hooks/inbox-watch.sh`. If a watcher is already armed, no-op." This matches the deliberation-primitive shape: goal stated, literal action conditioned on a check. Even if a future change reintroduces emission on resume paths, literal compliance produces correct behavior.

Both fixes ship in a single PR. Source-gate alone would satisfy the immediate bug; prompt rewrite alone would not (literal compliance still produces a duplicate on a coordinator that doesn't run the verify check). Combined: structural elimination on the known-failing path + verbal hardening as defense-in-depth.

## Tasks

### T1 — xfail tests for source gate and prompt shape (TDD, Rule 12)

- kind: test
- estimate_minutes: 25
- files: `scripts/hooks/tests/inbox-watch-test.sh`
- detail: Existing tests `test_bootstrap_silent_on_resume`, `test_bootstrap_silent_on_clear`, `test_bootstrap_silent_on_compact` (lines 383–402) already encode the desired source-gate behaviour but currently fail against the live impl (impl emits on those sources). Confirm they execute as live tests (not skipped) and run red as the xfail floor. Add three new tests: (a) `test_bootstrap_directive_uses_verify_then_arm_shape` — assert the emitted `additionalContext` on `source=startup` contains both "verify" (case-insensitive) and "no-op" (or equivalent "already armed"/"otherwise" wording) AND retains the Monitor + `inbox-watch.sh` references; (b) `test_bootstrap_directive_does_not_say_before_anything_else` — assert the literal phrase "before doing anything else" is absent from the emitted context (regression floor for the old literal form); (c) `test_bootstrap_directive_references_ps_check` — assert the context mentions `ps` or `Monitor tasks` so the verify step is operationally specified. Wire all three under `run_xfail` initially. Commit must reference plan slug `2026-04-25-watcher-arm-directive-source-gate` to satisfy TDD-gate.
- DoD: `bash scripts/hooks/tests/inbox-watch-test.sh` runs the new + existing tests; the four bootstrap-source/shape tests fail (xfail-floor). No other tests regress. Commit prefix `chore:` (test file, not under `apps/**`).

### T2 — Source gate: narrow the case allowlist to startup-only

- kind: code
- estimate_minutes: 10
- files: `scripts/hooks/inbox-watch-bootstrap.sh`
- detail: Edit the `case "$source_val" in` block at lines 39–42. Replace `startup|resume|clear|compact) ;;` with `startup) ;;`. Update the file header comment block (lines 11–13) to reflect the new behaviour: "source not in {startup} → exit 0 silently". Add a one-line comment on the case line referencing the plan slug and the failure mode (literal-vs-goal duplicate-process bug). No other behavioural changes in T2.
- DoD: After T2 alone, `test_bootstrap_silent_on_resume`, `test_bootstrap_silent_on_clear`, `test_bootstrap_silent_on_compact` pass. `test_bootstrap_emits_json_on_startup` still passes (no change to startup path yet).

### T3 — Verify-then-arm prompt rewrite

- kind: code
- estimate_minutes: 15
- files: `scripts/hooks/inbox-watch-bootstrap.sh`
- detail: Replace the `context=` assignment at line 98 with the verify-then-arm wording. Proposed text (single line, no embedded quotes/backslashes — preserves the manual-JSON fallback at line 107): `context="FIRST ACTION REQUIRED: verify a watcher is armed for ${display_name} — check existing Monitor tasks and run ps aux | grep inbox-watch.sh matched against your CLAUDE_AGENT_NAME. If a watcher is already armed, no-op. If absent, invoke Monitor with command: bash scripts/hooks/inbox-watch.sh — description: Watch ${display_name}'s inbox. Events surface as INBOX: <file> lines; when one appears, run /check-inbox."` Verify the manual-JSON sed escaping at line 108 still produces valid JSON for the new string (no double-quotes added, no backslashes added — the new text is safe).
- DoD: After T3, all four new T1 tests pass. The existing `test_bootstrap_emits_json_on_startup` still passes (Monitor + `inbox-watch.sh` + agent name still grep-able). Promote all six bootstrap-related tests from `run_xfail` to `run_real` if a parallel real-test slot exists; otherwise leave under `run_xfail` (the wrapper aliases to `run_real` per line 38, so this is cosmetic).
- DoD-extra: `printf '{"source":"startup"}' | CLAUDE_AGENT_NAME=evelynn bash scripts/hooks/inbox-watch-bootstrap.sh | jq .` returns valid JSON.

### T4 — Manual smoke + memory note

- kind: ops
- estimate_minutes: 10
- files: `agents/karma/memory/karma.md` (append session note)
- detail: From a clean clone, simulate each source value (`startup`, `resume`, `clear`, `compact`) via `printf '{"source":"<src>"}' | CLAUDE_AGENT_NAME=evelynn bash scripts/hooks/inbox-watch-bootstrap.sh`. Confirm: startup emits JSON with verify-then-arm wording; resume/clear/compact emit nothing. Capture the four outputs in the PR description. Append a one-paragraph memory note to `agents/karma/memory/karma.md` recording the literal-vs-goal pattern (link to the PR # and Sona's inbox file) so future quick-lane plans recognise the shape.
- DoD: Smoke transcripts in PR body; memory shard appended.

## Test plan

Tests cover the two invariants this plan ships:

1. **Source-gate invariant** — directive is emitted iff `source=startup`. Protected by `test_bootstrap_emits_json_on_startup` (positive on startup) plus `test_bootstrap_silent_on_resume`, `test_bootstrap_silent_on_clear`, `test_bootstrap_silent_on_compact` (negative on each non-startup source). These three negative tests already exist (lines 383–402 of `inbox-watch-test.sh`); T1 only confirms they run live. If a future change reintroduces emission on a non-startup source, all three fire.

2. **Verify-then-arm prompt-shape invariant** — the emitted directive on startup states a verify step before the arm step, so literal compliance produces correct behaviour. Protected by three new tests added in T1: positive shape match (`verify` + `no-op`/`already armed` + Monitor/`inbox-watch.sh`); regression floor (literal "before doing anything else" absent); operational specificity (`ps` or `Monitor tasks` referenced). If a future copy-edit reverts to the old literal form, all three fire.

Out of scope: the upstream `inbox-watch.sh` watcher itself; the coordinator-identity hook (it emits no watcher directive); the `posttooluse-monitor-arm-sentinel.sh` post-arming sentinel (orthogonal).

Run command: `bash scripts/hooks/tests/inbox-watch-test.sh`. CI path: existing hook-tests workflow.

## Open questions

None. Sona's combined fix recommendation, plan author's verification of the directive's actual location, and the existing test scaffolding leave no ambiguity.

## References

- `agents/evelynn/inbox/20260425-0729-102180.md` — Sona's bug report (the triggering incident).
- `scripts/hooks/inbox-watch-bootstrap.sh:39-42, 98` — the two emission sites this plan modifies.
- `scripts/hooks/tests/inbox-watch-test.sh:372-402` — the existing bootstrap source-gate tests this plan activates.
- PR #49 — deliberation-primitive shipping the literal-vs-goal pattern this plan instances.
- PR #51 — prior source-gate extension on a related hook (referenced as the established gate-extension pattern).

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan is well-scoped with a clear owner (karma), four concrete tasks with estimates totaling ~60min, and TDD-first ordering per Rule 12 (T1 lands xfail tests before T2/T3 implementation). The two-pronged fix is justified: source-gate eliminates the failure structurally on the known-failing path, and the verify-then-arm rewrite hardens any remaining emission surface — each prong serves a named invariant captured by tests. Open questions are explicitly resolved; existing test scaffolding at lines 383–402 already encodes the source-gate invariant. No TBDs, no speculative extensibility, single PR.
