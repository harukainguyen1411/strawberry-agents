# PR #24 Rule-18 Self-Merge Amendment — Re-Review

**Date:** 2026-04-22
**PR:** #24 `feat/rule-18-self-merge-amendment`
**Verdict:** APPROVED (advisory lane, strawberry-reviewers-2)

## Prior Findings (CHANGES_REQUESTED)

1. `architecture/cross-repo-workflow.md` retained stale "must never merge their own PRs" phrasing — a propagation miss.
2. Gate (c) "no red required check" in CLAUDE.md rule 18 was tautological with gate (a) "all required status checks green".
3. Amendment wording "once (b) is satisfied" was incomplete — should reference both (a) and (b).

## Fix Verification

All three resolved in commit `90473d7` (+ test broadening in `35eaf58`):
- Stale phrase replaced with canonical wording.
- Gate (c) tautology dropped in CLAUDE.md, pr-rules.md, agent-network.md.
- Wording updated to "once (a) and (b) are satisfied" in all three sites.
- Regression test `scripts/hooks/tests/test-rule-18-amendment.sh` now 6/6 PASS with new assertion 6 guarding the phrasing Talon missed on first pass.

## Residual (Advisory)

`architecture/cross-repo-workflow.md` reintroduces a three-gate structure (a)/(b)/(c) where the new (c) = "no branch-protection bypass". This is redundant with the opening sentence of the paragraph but not contradictory. Canonical rule in CLAUDE.md is two gates. Flagged as non-blocking doc redundancy — safe to leave or clean up later.

## Lessons

- When finding #2 is "tautological gate", re-check sibling docs don't reintroduce the same pattern under a different label. cross-repo-workflow.md technically satisfied the letter of the feedback (dropped gate (c) = "no red check") but immediately added a different gate (c) = "no bypass" that repeats the opening clause. Caught on re-review; worth being explicit in the original finding.
- Test assertion 6 is a good template for phrasing-drift guards: rg across architecture/ + agents/memory/ for any alternate restatement of a deprecated rule clause. Broadens T4 from a single-phrase check to a multi-phrase regression net.
