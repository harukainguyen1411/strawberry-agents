---
date: 2026-04-26
pr: 91
verdict: approved-with-drift-note
---

# PR #91 — lint-missing-block-cleanup (Talon, follow-up to Senna PR #87 call-out)

## Charter
Mechanical: resolve 29 MISSING_BLOCK lint violations across `.claude/agents/*.md`. Add 2 new `_shared/*-rules.md` files, wire include markers into 28 defs, surgical fix on swain, add `swain` to `OPUS_AGENTS` list. End state: lint 0 drift, bats 32/32.

## Verification done
1. **Canonical content extraction faithful** — diffed new `_shared/sonnet-executor-rules.md` and `_shared/opus-planner-rules.md` against pre-existing `SONNET_REF` / `OPUS_REF` string literals in `lint-subagent-rules.sh` on main. Byte-identical. No invented content.
2. **Swain surgery** — simplicity bullet correctly extracted to standalone paragraph; canonical block now matches reference. End-session line semantically inverted (was "Always run, do not wait for Evelynn" → now "only when Evelynn instructs") because the canonical reference already used the latter; Swain was the outlier. Documented as a behavioral note, not a block.
3. **OPUS_AGENTS update** — adding `swain` is correct. But the bigger drift remained unaddressed.

## Drift note surfaced (not blocking)
17 agents have `model: opus`. `OPUS_AGENTS` list in lint script only contains 10. The 7 omitted (karma, xayah, sona, evelynn, lucian, senna, orianna) were given the SONNET-EXECUTOR canonical block by this PR. For karma/xayah/sona/evelynn — whose declared roles are explicitly planner/synthesizer/coordinator — the executor block's lead bullet ("never design plans yourself") directly contradicts their `description` and `role_slot`. Lint passes only because the script's hand-curated list silently divorces tier classification from `model:` frontmatter. Pre-existing condition on main; this PR inherits and slightly widens it (the new `swain` entry is correct in isolation but does not fix the broader inconsistency).

Also stale: comment "evelynn is excluded — she has no .claude/agents/evelynn.md" is false — that file exists and got a block in this PR.

Recommended Karma-authored follow-up: decide canonical tier for each opus agent (planner vs reviewer vs coordinator vs gatekeeper), possibly add a third canonical block for reviewers/coordinators, reconcile `OPUS_AGENTS` with `model: opus` frontmatter or rewrite the comment.

## Lesson
When a "mechanical lint compliance" PR adds canonical blocks to many files at once, verify the **classification logic** (what determines block A vs block B) hasn't drifted from declared invariants. The lint passing 0/0 is necessary but not sufficient — the wrong block can still pass if the classifier is hand-curated. Read the script's stated invariant comment vs actual implementation.

## Outcome
Approved on charter fidelity. Drift note posted for future Karma plan.
