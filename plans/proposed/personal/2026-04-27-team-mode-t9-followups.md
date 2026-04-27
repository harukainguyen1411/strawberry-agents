---
slug: team-mode-t9-followups
concern: personal
project: agent-team-mode-comms-discipline
status: proposed
owner: karma
created: 2026-04-27
last_reviewed: 2026-04-27
tier: quick
complexity: quick
priority: P2
qa_plan: required
qa_co_author: senna
tests_required: true
related_decisions: [2026-04-27-team-mode-completion-signal]
related_plans:
  - plans/in-progress/personal/2026-04-27-agent-team-mode-comms-discipline.md
orianna_gate_version: 2
---

## Context

Senna's PR #110 re-review of the T9 dead-hook repair (head SHA `1b0b6df5` on main) cleared the
blocker but flagged two non-blocking IMPORTANT findings that must close before the parent
project (`agent-team-mode-comms-discipline`) reaches DoD. Both touch the same file —
`scripts/hooks/posttooluse-teammate-idle-marker.sh` — and its sibling test suite under
`tests/hooks/`.

**Finding 1 (correctness).** The repaired hook reads the teammate's `transcript_path` JSONL
and walks every SendMessage `tool_use` entry in that file to reconstruct the per-turn stream
of replies. Because the transcript is append-only and session-scoped, once a teammate emits a
`task_done` marker once in their session, every subsequent `TeammateIdle` event in that same
session will see a transcript still containing that historical marker — so the hook will
report "conformant" forever after, even when the teammate has gone silent on a new,
unrelated task. The hook silently degrades to a one-time check.

**Finding 2 (test coverage).** The new ~25-line python heredoc that parses
`transcript_path` JSONL has zero real-path test coverage. Every existing case in
`tests/hooks/test_teammate_idle_marker_hook.sh` and
`tests/hooks/test_teammate_idle_marker_hook_real_payload.sh` sets
`transcript_path: /tmp/nonexistent.jsonl` and routes through the `HOOK_SENDMESSAGE_FILE` env
override, so the actual JSONL parser has never executed under test. Finding 1's fix lives
inside that same heredoc — coverage gap is now load-bearing.

Quick-lane scope: two small, surgical fixes in one hook + one fixture and one test case.
No schema changes, no new external integration, single top-level domain (the team-mode
hook). Karma-appropriate.

## Tasks

### T1. xfail — turn-scoped walk regression

- kind: test
- estimate_minutes: 20
- files: `tests/hooks/test_teammate_idle_marker_hook.sh`
- detail: Add an xfail case `case_5_turn_scope_after_prior_task_done` that constructs a
  `HOOK_SENDMESSAGE_FILE` JSON array containing two SendMessage `tool_use` entries — first
  one carries a `task_done` marker for task `T-prior`, second one is a plain status update
  for task `T-current` with no marker. Invoke the hook with a `TeammateIdle` payload
  referencing `T-current`. Assert the hook reports "non-conformant" (no marker for the
  current turn). Today's whole-transcript walk will see the historical `task_done` and
  incorrectly report conformant — case must be xfail-tagged referencing this plan T2.
- DoD: case present, runs, fails as expected; suite still green overall (xfail counted as
  expected failure by the test harness convention already used for `*_real_payload.sh`).

### T2. impl — scope SendMessage walk to current turn

- kind: code
- estimate_minutes: 60
- files: `scripts/hooks/posttooluse-teammate-idle-marker.sh`
- detail: In the python heredoc that parses `transcript_path` JSONL, change the SendMessage
  walk from "all entries" to "current-turn only". Research the transcript JSONL shape first
  — the canonical delineator is the most recent `UserPromptSubmit` event (or, equivalently
  for teammate sessions, the most recent inbound message that opened the current work
  cycle). Walk the JSONL backward from the tail; collect SendMessage `tool_use` inputs
  until you hit the delineator; stop. The `HOOK_SENDMESSAGE_FILE` override path is unchanged
  (tests can still inject a synthetic per-turn array). Flip T1's xfail to expect-pass in
  the same commit.
- DoD: T1 case passes; all prior cases still pass; hook still under 150 lines; no new
  external dependencies.

### T3. xfail — real-path JSONL parser uncovered

- kind: test
- estimate_minutes: 20
- files: `tests/hooks/test_teammate_idle_marker_hook_real_payload.sh`,
  `tests/hooks/fixtures/teammate-idle-conformant-turn.jsonl` (new). <!-- orianna: ok -->
- detail: Add an xfail case `case_real_jsonl_fixture_conformant` that points
  `transcript_path` at a checked-in fixture JSONL containing a realistic shape: a
  `UserPromptSubmit`, then one or two SendMessage `tool_use` entries the last of which
  carries a `task_done` marker. Do NOT set `HOOK_SENDMESSAGE_FILE`. Assert the hook
  reports "conformant". Today this either errors (parser path never tested) or silently
  no-ops; mark xfail referencing T4.
- DoD: fixture file present, case runs, fails as expected.

### T4. impl — wire real-path coverage; fix any parser bugs surfaced

- kind: code
- estimate_minutes: 40
- files: `scripts/hooks/posttooluse-teammate-idle-marker.sh`,
  `tests/hooks/test_teammate_idle_marker_hook_real_payload.sh`
- detail: Run T3; fix whatever the real-path JSONL parser surfaces (likely candidates: line
  iteration vs `json.loads` of the whole file, key path into the `tool_use.input`
  structure, handling of non-SendMessage `tool_use` entries interleaved in the transcript).
  Add a second fixture-backed case `case_real_jsonl_fixture_nonconformant` that mirrors T1
  via real fixture (no marker on the current turn) for symmetry. Flip T3 to expect-pass.
- DoD: both fixture-backed cases pass; T1/T2 cases still pass; suite green; coverage of
  the JSONL parser real path now non-zero.

## QA Plan

**UI involvement:** no

Inline (quick-lane). Two-reviewer policy applies: Lucian (functional) + Senna (sanity)
on the impl PR. Self-merge by Karma's pair-mate (Talon) once both reviews APPROVE and
required checks are green; no `--admin` bypass.

**Invariants the new tests protect:**

1. The idle hook makes a per-turn judgement, not a per-session one. A teammate that was
   conformant earlier in the session can be flagged non-conformant on the current turn.
2. The transcript-JSONL parsing path actually executes in CI (no more env-override-only
   coverage); a fixture regression will fail the suite.

**Test commands:**

```
bash tests/hooks/test_teammate_idle_marker_hook.sh
bash tests/hooks/test_teammate_idle_marker_hook_real_payload.sh
```

Both must exit 0 with all cases (including the new T1/T3-derived ones, post-flip)
reporting PASS.

**Manual verification (post-merge, optional):** spin a real teammate session, send two
sequential tasks, observe that a `task_done` on task A does not mask a missing marker on
task B. Capture in `assessments/personal/` if anomalies appear; otherwise no artifact
required.

## TDD Discipline

Per universal invariant #12 — each impl commit (T2, T4) MUST be preceded on the same
branch by its corresponding xfail commit (T1, T3). Order on the branch:

1. T1 xfail commit (test only, references this plan)
2. T2 impl commit (flips T1 xfail → pass)
3. T3 xfail commit (test + fixture only, references this plan)
4. T4 impl commit (flips T3 xfail → pass; adds symmetry case)

Pre-push hook + `tdd-gate.yml` enforce.

## Open questions

None expected. If T2's research into the transcript JSONL shape reveals that
`UserPromptSubmit` is not the right delineator for teammate-session transcripts (e.g.
teammate sessions are driven by inbound SendMessage, not UserPromptSubmit), Talon should
note the alternative chosen in the impl commit body and move on — no plan amendment
required for that level of detail.

## References

- Parent project: `projects/personal/active/agent-team-mode-comms-discipline.md`
- Parent plan: `plans/in-progress/personal/2026-04-27-agent-team-mode-comms-discipline.md`
- Repair commit head: `1b0b6df5` (T9 hook rewire to `TeammateIdle`)
- Related decision: `2026-04-27-team-mode-completion-signal`
