---
tier: quick
complexity: quick
owner: karma
impl-set: [talon]
status: proposed
priority: P1
last_reviewed: 2026-04-27
orianna_gate_version: 2
tests_required: true
qa_plan: inline
parent_adr: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md
parent_amendment_sha: e07bf8ad
---

# Helper retrofit — ms-precision timestamp contract (§D6.2)

## Why

Azir ADR amendment 4 (`e07bf8ad`) canonized §D6.2: every state-DB write to an ISO-8601 timestamp column MUST use `strftime('%Y-%m-%d %H:%M:%f','now')` (23-char ms-precision), not `datetime('now')` (19-char second-precision). The motivation is cross-coordinator ordering correctness — under WAL with concurrent writers, second-precision ties fall back to rowid order, which is implementation-defined and can render the same two events in different orders to different readers. Lex-sortability of the fixed-width 23-char form preserves chronological order even when mixed with legacy second-precision rows.

Three already-shipped helpers from PR #103 (Viktor T6b) write authored-entity rows: `scripts/state/db-write-session.sh`, `scripts/state/db-write-learning.sh`, and `scripts/capture-decision.sh`. §D6.2 line 420 names these as the gap. Refresh-script writes (PR #104, Jayce T4b) already use the canonical form and serve as the reference pattern.

This plan retrofits the three helpers and tightens their test surface. Single-line per helper, no schema migration, no data migration (per §D6.2 lex-sortability invariant).

## What changes (per-file delta)

### 1. `scripts/state/db-write-session.sh`
Currently binds caller-supplied `STARTED_AT` and `ENDED_AT` (ISO-8601 strings of arbitrary precision) directly into the INSERT. The contract is satisfied at the SQL boundary, not at the bash boundary, so the helper must normalise into ms-precision shape. Two acceptable shapes (Talon picks the simpler):
- **Shape A (preferred — surgical):** wrap each non-empty caller value in a SQL coercion `strftime('%Y-%m-%d %H:%M:%f', <value>)` so any input precision (date-only, second, ms) is normalised to 23-char width on write.
- **Shape B (fallback):** validate `STARTED_AT`/`ENDED_AT` match `^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}$` and reject (exit 0 with WARNING per existing non-fatal contract) on mismatch.

Choose Shape A. It preserves the helper's non-fatal posture and matches Jayce's `_esc`/SQL-side pattern in `refresh-prs.sh`. `nullif(...,'')` wrapping for `ENDED_AT` is preserved by composing `nullif(strftime('%Y-%m-%d %H:%M:%f', '<esc>'), strftime('%Y-%m-%d %H:%M:%f', ''))` — equivalent under SQLite (strftime of empty string returns NULL, so the nullif still elides empty input).

### 2. `scripts/state/db-write-learning.sh`
Identical retrofit shape applied to `LEARNED_AT`. `LEARNED_AT` is required (not nullable), so a plain `strftime('%Y-%m-%d %H:%M:%f', '<esc>')` wrap suffices.

### 3. `scripts/capture-decision.sh`
`decided_at` is currently bound from the markdown frontmatter `date:` field (date-only, e.g. `2026-04-27`). §D6.2 mandates ms-precision in the column. Two interpretations exist; resolve to **(b)** below — see Open questions:
- (a) Treat `decided_at` as wall-clock-when-decided → write `strftime('%Y-%m-%d %H:%M:%f', '<frontmatter-date>')` (yields `2026-04-27 00:00:00.000`, lex-sortable, preserves date semantics).
- (b) Treat `decided_at` as wall-clock-when-recorded → write `strftime('%Y-%m-%d %H:%M:%f','now')` ignoring the frontmatter date.

Pick **(a)**. It preserves authored intent (the human chose the decision date), satisfies §D6.2 width invariant, and is consistent with Shape A above. Open question 1 escalates to Azir if (b) is the intended reading.

## Test (xfail-first)

Add `scripts/state/__tests__/helpers-ms-precision.xfail.bats` (new). One failing test per helper that:
1. Spins up a fresh ephemeral state DB via `_lib_db.sh` schema.
2. Invokes the helper with representative args (for `db-write-session.sh`: a second-precision `started_at` like `2026-04-27 10:00:00`; for `db-write-learning.sh`: same; for `capture-decision.sh`: a temp markdown shard with frontmatter `date: 2026-04-27`).
3. Selects the relevant timestamp column from the row written.
4. Asserts the value matches `^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}$` (23 chars, fixed-width ms).

The test file MUST be `.xfail.bats` and committed BEFORE the impl commit on the same branch (Rule 12). After impl lands, Talon renames `.xfail.bats` → `.bats` in the same impl PR per the existing project xfail→pass promotion convention (verify against repo precedent in T6a).

Also tighten the existing T6a helper test surface (`scripts/state/__tests__/` — locate the T6a-tagged file) to add the same regex assertion alongside the existing functional assertions. Per ADR §D6.2 line 426: "T6a (existing xfail) extended to assert every column listed above is populated with a 23-character `YYYY-MM-DD HH:MM:SS.fff` string after a write."

## Tasks

### T1 — xfail test scaffold (kind: test, est: 20m)
- **Files:** `scripts/state/__tests__/helpers-ms-precision.xfail.bats` (new). <!-- orianna: ok -->
- **Detail:** Author the failing test described in §Test above. Exercise all three helpers in separate `@test` blocks. Use the existing `_lib_db.sh` for ephemeral DB setup (mirror the bootstrap pattern from any sibling `*.xfail.bats` in `scripts/__tests__/`).
- **DoD:** Test commits cleanly, runs red against current `main` (all three @test blocks fail with regex mismatch), commit message uses `chore:` prefix and references this plan.

### T2 — retrofit `scripts/state/db-write-session.sh` (kind: impl, est: 15m)
- **Files:** `scripts/state/db-write-session.sh`.
- **Detail:** Wrap `STARTED_AT` binding in `strftime('%Y-%m-%d %H:%M:%f', '<esc>')`; wrap `ENDED_AT` binding in `nullif(strftime('%Y-%m-%d %H:%M:%f', '<esc>'), '')` (or equivalent — the goal is empty caller string still produces SQL NULL). Verify with the T1 test for sessions.
- **DoD:** `helpers-ms-precision.xfail.bats` sessions block flips green; existing `scripts/state/__tests__/` session tests remain green.

### T3 — retrofit `scripts/state/db-write-learning.sh` (kind: impl, est: 10m)
- **Files:** `scripts/state/db-write-learning.sh`.
- **Detail:** Wrap `LEARNED_AT` binding in `strftime('%Y-%m-%d %H:%M:%f', '<esc>')`. No nullif needed (column is NOT NULL).
- **DoD:** `helpers-ms-precision.xfail.bats` learnings block flips green; existing learning tests remain green.

### T4 — retrofit `scripts/capture-decision.sh` (kind: impl, est: 15m)
- **Files:** `scripts/capture-decision.sh` (around line 183-190).
- **Detail:** Per §What changes (3) interpretation (a): wrap `DECISION_DATE` binding in `strftime('%Y-%m-%d %H:%M:%f', '<esc>')`. Yields `YYYY-MM-DD 00:00:00.000` for date-only frontmatter input.
- **DoD:** `helpers-ms-precision.xfail.bats` decisions block flips green; `scripts/test-decision-capture-skill.sh` and `scripts/test-decision-capture-lib.sh` remain green.

### T5 — extend T6a assertions to cover ms-precision (kind: test, est: 15m)
- **Files:** locate the T6a-tagged xfail file under `scripts/state/__tests__/` or `scripts/__tests__/` (grep for `T6a` and `Rakan`); add the 23-char regex assertion to every helper write covered there.
- **Detail:** Per ADR §D6.2 line 426. Single new assertion per `@test` block; do not restructure existing tests.
- **DoD:** T6a continues to behave as xfail (or stays green per its current state) with the added assertions exercised.

### T6 — promote new xfail to passing (kind: test, est: 5m)
- **Files:** rename `scripts/state/__tests__/helpers-ms-precision.xfail.bats` → `scripts/state/__tests__/helpers-ms-precision.bats`.
- **Detail:** Only after T2-T4 are committed and the test runs green locally. Standard project convention for xfail→pass promotion.
- **DoD:** Renamed file in same PR as the impl commits; CI sees the test as a regular bats file.

## Acceptance

- All three helpers, when invoked with caller-supplied second-precision (or date-only) timestamps, produce rows whose timestamp columns are 23-char ms-precision strings matching `^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}$`.
- New test `scripts/state/__tests__/helpers-ms-precision.bats` (post-T6) is green.
- Existing helper tests under `scripts/state/__tests__/` and `scripts/test-decision-capture-*.sh` remain green.
- T6a (Rakan helper test surface) carries the ms-precision regex assertion per ADR §D6.2 line 426.
- No schema migration. No data migration. Existing rows untouched.
- PR body references `parent_adr` and `parent_amendment_sha` from frontmatter.

## Open questions

1. **`capture-decision.sh` `decided_at` semantics** — is the timestamp meant to be wall-clock-when-decided (frontmatter date, normalised to ms-precision via interpretation (a)) or wall-clock-when-recorded (`strftime('now')` ignoring frontmatter, interpretation (b))? Plan defaults to (a). If Azir/Duong prefers (b), T4 is a 1-line swap. Talon may proceed with (a) and flag in PR body for reviewer judgement.
2. **Locate T6a test file** — the ADR references "T6a (existing xfail)" without a path. Talon: grep `scripts/` for `T6a` tag at the top of xfail files; if ambiguous, defer T5 and ship T1-T4 + T6 as the first PR, follow up with T5 in a second PR.
3. **xfail→pass rename convention** — verify by inspecting at least one prior `*.xfail.bats` → `*.bats` rename in `git log` before T6. If the project convention is to delete-then-add rather than `git mv`, follow that.

## References

- Parent ADR: `plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md` §D6.2
- Amendment commit: `e07bf8ad`
- Reference impl pattern (already canonical): `scripts/state/refresh-prs.sh` lines 32-39, 84-91
- Original Viktor PR (the gap): PR #103
- Original Jayce PR (the canonical pattern): PR #104
- TDD invariant: CLAUDE.md Rule 12
