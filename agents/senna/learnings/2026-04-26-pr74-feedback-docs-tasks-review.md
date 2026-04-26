# PR #74 — feedback-docs-tasks (Talon) — Senna review

Date: 2026-04-26
PR: https://github.com/harukainguyen1411/strawberry-agents/pull/74
Verdict: CHANGES_REQUESTED
Review URL: https://github.com/harukainguyen1411/strawberry-agents/pull/74#pullrequestreview-4176672098

## Two-line summary

Talon's Leg-3 docs PR for feedback-system T4/T5/T6/T13a + decision-feedback T7/T11. Two correctness defects in the doc artifacts that will produce malformed runtime state when wired up; xfail tests have shell-portability bugs.

## Findings (filed, in priority order)

**C1 — feedback-consolidate/SKILL.md writes invalid `state: keep-open`.** The schema validator accepts only `open|acknowledged|graduated|stale`. `keep-open` is a Lux *verdict* label, not a file state. Mapping bug: keep-open verdict → leave `state: open`, not write `state: keep-open`. Will fail `feedback-index.sh --check` on first live digest run.

**C2 — Lissandra Step 6c ordering note contradicts protocol position.** Note says "MUST run after shard write because `decision_source` refs may point to shard UUID." But 6c is positioned at `2c.` BEFORE the session shard write at Step 3. Either the rationale is inverted (6c must run before shard write so refs are coherent) or the position is wrong. Architecture doc §5 has a similar inconsistency vs canonical `/end-session` step numbering.

**I1 — `count_open_high` boot-chain instruction not derivable from INDEX.md.** Boot text says "If `count_open_high > 0`" but INDEX summary line is `Open: N | High: H | Medium: M | Low: L`. No literal `count_open_high` field. Plan §698 acknowledged this is a conceptual name "derived from `High: H`" but boot text doesn't tell the LLM how. Risk: coordinator either grep-misses or hallucinates.

**I2 — TT4-E/F bats use `fail` (bats-assert helper) without `load 'bats-support/load'`.** Plain bats lacks `fail`. Also: `refute_match()` defined-never-called dead code; `\b` regex is GNU-grep-specific, not portable to macOS BSD grep per Rule 10.

**S1, S2, S3 — soft notes:** dead reference to `/agent-feedback` skill not yet existing; `_shared/feedback-trigger.md` has no include marker yet (correct per task graph but worth flagging deferred status); architecture cross-refs unverified.

## What I learned

1. **`keep-open` confusion vector.** When a plan introduces a verdict-label vocabulary (`graduate`/`keep-open`/`stale`) that overlaps with file-state vocabulary (`open`/`graduated`/`stale`), the impl tends to conflate them. Watch for this pattern in any future categorization-then-mutate skill: verdict ≠ state. The plan's §D1 frontmatter is the source of truth for valid file states; verdict labels live in skill prose.

2. **Boot-chain instruction discipline.** When a plan says "boot text refers to derived field by name only," the impl needs to either (a) make the field name literally appear in the source file (write `count_open_high: 2` in INDEX.md) or (b) tell the boot text reader how to compute it from what's actually present. Otherwise the LLM hits an instruction-with-no-grounding and degrades silently. Quasi-named-fields in instructions are an anti-pattern.

3. **xfail bats hygiene without bats-assert.** Several xfail bats files in this repo invoke `fail` without loading bats-assert. The framework treats missing functions as failing-but-confusing. Either standardize on loading bats-assert (one line `load 'test_helper/bats-support/load'`) at the repo level, or use `printf '...\n' >&2; return 1` which is portable and self-documenting. Worth raising as a cross-cutting cleanup pattern when it next causes pain.

4. **Ordering rationale inversions.** When a sequence note says "must run after X for reason R", check that the sequence position is actually after X. This is a common doc-defect class — easy to miss because reviewers naturally trust the rationale prose without cross-checking the surrounding step numbers.

## Process notes

- `scripts/reviewer-auth.sh --lane senna` preflight returned `strawberry-reviewers-2` cleanly.
- No AI-attribution scan hits in commit messages or diff. Rule 21 (a)+(b)+(c) clean.
- Review verdict landed as CHANGES_REQUESTED at submit time.
- I scoped strictly to code-quality / security / tests / edge-cases per Senna's lane. Did not judge ADR fidelity or whether T7/T8 should have ridden along — that's Lucian's lane.

## Re-review (2026-04-26, commit 8394de0e) — APPROVED

Talon addressed all four findings cleanly in one commit:

- **C1 fixed:** `state: keep-open` → `state: open` (verdict→state mapping clarified, validator enum cited verbatim).
- **C2 fixed:** Step 6c moved from `2c` (after handoff shard) to `3b` (after session shard write); rationale rewritten to correctly cite Step 3's session-shard short-uuid as the `decision_source` ref target. Lissandra protocol now internally consistent with the architecture doc's own ordering claim.
- **I1 fixed:** boot-chain instruction in both Evelynn + Sona CLAUDE.md now references the actual INDEX summary-line shape (`Open: N | High: H | Medium: M | Low: L`) instead of the nonexistent `count_open_high` field. LLM has a concrete derivation path.
- **I2 fixed:** `fail` → `printf >&2; return 1`; `refute_match()` dead code dropped; `\b` → POSIX `[[:space:]]` anchors. Mirrored in TT4-F.

Bonus: TT4-C/D test names tightened from `count_open_high` to the actually-present content (`severity: high|High > 0|High: H`).

All 7 required CI checks SUCCESS. Rule 12 TDD ordering preserved. Rule 21 clean. APPROVE posted at 08:36:32Z superseding the prior CHANGES_REQUESTED.

Re-review meta-learning: when a fix commit updates both the impl and the xfail tests that gated it, double-check the test still asserts a meaningful property and didn't get loosened just to pass. In this case Talon actually tightened the assertions (now checks for the real summary-line tokens), which is the correct direction.
