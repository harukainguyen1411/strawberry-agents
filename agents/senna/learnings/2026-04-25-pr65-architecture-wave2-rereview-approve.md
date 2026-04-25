# PR #65 architecture-consolidation Wave 2 — re-review APPROVE

**Date:** 2026-04-25
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/65
**Prior review:** `745Rft` (REQUEST_CHANGES; C1, C2, I1, I2/I3/I4 deferred, M1-M6)
**Re-review:** APPROVED at review id `745XAH` on commit `6ff07a55`.

## What was checked

Three fix commits on the PR branch:

- `8f3bc1c7` — cross-ref fixes (S-C1, S-C2, rollback.sh framing, typo)
- `4387ab46` — Lock-Bypass contract alignment (L-B1 path drift, S-I1 framing)
- `6ff07a55` — pr-rules cite (L-B2 Rules 14+19), Lissandra role, worktree cleanup, hooksPath edge case, placeholder cleanup

## Verification approach

1. `git show <sha>` for each fix commit — read the actual diff, not just the summary
2. `git show origin/architecture-consolidation-wave-2:<file>` to verify final state per file
3. Spot-checked all backtick-quoted file paths across the four touched files:
   - Scripts under `scripts/` and `scripts/hooks/` — all present
   - The corrected `plans/approved/personal/2026-04-21-coordinator-decision-feedback.md` — present
   - `architecture/canonical-v1.md` and `architecture/canonical-v1-bypasses.md` — absent (acknowledged deferral to W3)
4. Diff-scope check — only the targeted findings touched, no scope creep

## Key reasoning

**Deferral acceptance for S-I2/I3/I4 was sound** because the §Q6 wording is correctly *conditional*: "During measurement-week (while `architecture/canonical-v1.md` is active)..." — the contract is described but dormant until that file ships. This is honest signaling, not overclaiming a live regime. Documenting a contract that activates on a trigger file is fine; what would have been a blocker is documenting it as currently active when the trigger doesn't exist.

**S-I1 reframe was the most important fix.** The original wording said `--no-verify` Lock-Bypass violations are "treated as Rule 14 violations" — but Rule 14 is the universal `--no-verify` ban, not a Lock-Bypass enforcement mechanism. The reframe sources the prohibition correctly from Rule 14, then explicitly says "Hook-side enforcement of this specific measurement-week rule is a follow-up deliverable (W3)." This closes the bypass-abuse risk window because readers no longer believe a hook will catch them — discipline is reviewer-attention until W3 hooks land.

## Pre-existing debt observed (NOT raised as blocker)

`git-workflow.md` references `.github/workflows/{unit-tests.yml,e2e.yml}` in the branch-protection required-checks table, but neither workflow file exists in the repo. This content was *carried over verbatim* from the legacy `architecture/git-workflow.md` (already on main) and `architecture/agent-network-v1/testing.md` (W1, already merged). Pre-existing tracked debt across the testing-pipeline plans, not a regression introduced by Wave 2. Flagged as informational in the review body, not a blocker.

## Pattern

- **Re-review verification rhythm**: prior-finding-list → diff each fix commit → final-state file read → cross-ref spot-check → confirm no scope creep. Don't trust the PR body's claims; verify each fix lands the way the body describes.
- **Conditional language as deferral mechanism**: when a doc describes a contract activated by a trigger file that doesn't exist yet, that's honest if the conditional is explicit ("while X is active") and dishonest if the conditional is hidden ("X is in effect"). Wave 2 got it right.
- **Categorization correctness matters**: framing a violation as "Rule N violation" creates an enforcement expectation. If Rule N's tooling won't actually catch the violation, that framing must be replaced with truthful enforcement-state language.
