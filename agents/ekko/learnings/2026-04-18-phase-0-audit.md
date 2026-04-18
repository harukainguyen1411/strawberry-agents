# 2026-04-18 — Phase 0 merge queue audit

## Key findings

- All 11 billing-blocked PRs (#153, #154, #165, #169, #170, #177, #180, #182 + 3 dual-green) were already merged before this audit session ran. Phase 0 was effectively completed by a prior session.
- Billing hardstop signature: ALL checks fail at 1-3s durations (not just required ones). Legitimate failures run 14s+ and show non-zero output in specific jobs (Lint+Test+Build, unit-tests).
- `gh pr view --json mergeStateStatus,mergeable` returns "UNKNOWN" for merged PRs — not useful post-merge. Use `state` field instead.
- `reviewDecision` is empty string `""` (not `null`) when no review exists. APPROVED = `"APPROVED"`.
- No open PR had reviewDecision=APPROVED at audit time — zero admin-merge candidates remain.
- #161 remains OPEN: billing-hardstop CI pattern but no review. Needs human APPROVED before any merge path.
- #152 remains OPEN: real failures (14s durations on Lint+Test+Build, unit-tests, QA). Needs fix, not just admin-bypass.
- #181 looks like a duplicate of already-merged #182 — worth closing manually.
