# PR #64 round-2 re-review — APPROVE after 9-commit fix train

**Date:** 2026-04-25
**PR:** #64 viktor-rakan/coordinator-decision-feedback (Plan B)
**Verdict:** APPROVE (strawberry-reviewers-2)
**Review URL:** https://github.com/harukainguyen1411/strawberry-agents/pull/64#pullrequestreview-PRR_kwDOSGFeXc745hl-

## Round-1 → round-2 deltas verified

| Finding | Round-1 severity | Round-2 status |
|---------|------------------|----------------|
| B1 match_rate uses count_a not match_count | CRITICAL | Fixed in 6f41f4ce; svd-7 fixture added; 86% confirmed by bats run |
| I1 agent-def stdin wording vs --file contract | important | Fixed in b105c0fd |
| I2 decision_id path-traversal | important | Fixed at both lib and entrypoint (a772bca2) |
| I3 DECISION_RENAME_* unconditional honour | important | Partial fix (93fa5002) — accessors gated, validators not. Reclassified S3 advisory |
| I4 lock below short-circuit | important | Fixed (446d269b) |

## Re-review scope discipline

The fix-train carried collateral nits (trap cleanup, axis-header regex, infer_slug exhaustion error) bundled in c664fef7. Reviewed each on the merits but flagged none — all clean.

Two test scripts (`test-decision-capture-skill.sh`, `test-end-session-step-6c.sh`) were missed by the assert-mode flip in c664fef7 — flagged as S2 but not blocking.

The `T5-skill-stdin-pipe-documented` xfail is now semantically stale post-I1 (S1) — it greps for "stdin" which I1 correctly removed.

## Pattern noted: partial-scope fix vs commit-message claim

I3 commit message says "they must not fire in prod" but the patch only gates the field-name accessors, not the bind-contract validator branches that ALSO trip on `DECISION_RENAME_*` presence. In prod, an accidentally-set env var still fails decisions loud.

I called it advisory rather than blocking because:
1. Functional behaviour in prod is correct (canonical fields).
2. Tripwire is fail-loud, not silently-corrupting.
3. Threat model requires env-var write access (already privileged).

But for a more rigorous lane, this counts as "fix doesn't fully match commit msg" — reviewer should flag the gap even if non-blocking.

## Verification methodology that worked

1. Read commit messages chronologically.
2. For each verification item, locate the actual changed lines (grep + Read).
3. Run the relevant test files (bats + .sh).
4. Cross-check fixtures vs expected output (svd-1..7 manual count of a/b/c/match for B1).
5. Drop concerns down severity tiers when threat model is weak.

Total tests run: 15 + 10 (.sh) + 70 (bats across 9 files). All green.

## Senna lane discipline

Resisted commenting on plan §3.5/§4.3/§6 fidelity even when the impl had to be reasoned through plan invariants — that's Lucian's lane. Stuck to: does the formula compute the documented quantity? Does the path-traversal regex reject the documented inputs? Did the lock-acquisition placement actually cover the short-circuit branch?
