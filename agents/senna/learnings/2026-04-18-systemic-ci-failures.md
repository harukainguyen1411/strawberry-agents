---
date: 2026-04-18
topic: systemic-ci-failures
---

# Systemic CI Failures — Infrastructure Issue

On 2026-04-18, all CI checks across all branches (not just reviewed PRs) were returning FAILURE. Log retrieval via `gh run view --log-failed` returned "log not found", confirming these are infrastructure stubs, not real test failures.

**Rule:** When all CI checks fail uniformly across unrelated branches, treat as infrastructure issue — do not block PRs on CI red alone. Verify by checking `gh run list` across multiple branches before concluding PR-specific failure.
