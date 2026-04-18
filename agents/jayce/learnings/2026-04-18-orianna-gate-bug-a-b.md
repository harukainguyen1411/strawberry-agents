# Jayce Learning — 2026-04-18 — Orianna gate Bug-A and Bug-B

## Context

Fixed two pre-v1 bugs in the Orianna plan fact-check gate caught by Vi in the dogfood re-run.

## Bug A — Report picker prefix collision

**Root cause:** `orianna-fact-check.sh` used `${PLAN_BASENAME}-*.md` as the report picker glob. When the plan basename was `2026-04-19-orianna-fact-checker`, this also matched `2026-04-19-orianna-fact-checker-tasks-<timestamp>.md` (the tasks plan's reports), causing the script to read the wrong report's `block_findings` count.

**Fix chosen:** `${PLAN_BASENAME}-[0-9]*.md` — ISO timestamps always begin with a year digit. Plan-variant suffixes (like `-tasks-`) insert a non-digit word at that position, so they cannot match. This is more robust than extracting the exact path from the claude invocation because the LLM writes the report itself (filename not under our control).

**Alternative considered:** Extract exact path before invoking claude, then check that exact path. Rejected because we'd have to pre-generate the timestamp and pass it to the LLM via prompt, adding coupling.

## Bug B — orianna:ok suppression

**Root cause:** `fact-check-plan.sh` had a comment saying "Strip orianna-suppressed tokens" but no implementation. `agents/orianna/prompts/plan-check.md` had a one-liner that didn't cover the preceding-line case.

**Fix:** Modified the `extract_tokens` awk block in `fact-check-plan.sh` to track a `suppressed` flag and `suppress_next` flag. Lines containing `<!-- orianna: ok -->` set `suppressed=1`; if the line is only the marker (standalone), it also sets `suppress_next=1` for the next line. Updated the LLM prompt with explicit two-case rules. Added §8 "Suppression syntax" to `claim-contract.md` (old §8 "Scope boundary" shifted to §9).

## Patterns

- **Glob precision matters for basename collision:** always use `[0-9]*` or similar anchors when the glob suffix must match ISO timestamps but not word-variant suffixes.
- **awk `suppress_next` pattern** is clean for single-line lookahead suppression in extraction loops — avoid multi-pass approaches when awk state variables suffice.
- **xfail tests for static code properties** (e.g. "grep for `[0-9]` in the script file") are useful for anchoring correctness guarantees that survive future edits.

## Files changed

- `scripts/orianna-fact-check.sh` — [0-9]* glob fix + comment explaining why
- `scripts/fact-check-plan.sh` — suppression logic in extract_tokens awk block
- `agents/orianna/prompts/plan-check.md` — explicit suppression rules for LLM
- `agents/orianna/claim-contract.md` — new §8 Suppression syntax
- `scripts/__tests__/orianna-fact-check.xfail.bats` — 5 new tests (tests 13-17)

## PR

https://github.com/Duongntd/strawberry/pull/183
