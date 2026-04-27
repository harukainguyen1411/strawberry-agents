---
created: 2026-04-27
task: T.QA.10
plan: plans/approved/personal/2026-04-27-qa-enforcement-and-breakdown-discipline.md
---

# T.QA.10 — Regression PR Fixtures

This file records the fixture PRs opened as permanent regression references for the
`pr-no-qa-bypass` CI job deployed in T.QA.9.

## Fixture PR #107 — False-waiver pattern (RED — intentionally failing)

**PR URL:** https://github.com/harukainguyen1411/strawberry-agents/pull/107

**Purpose:** Demonstrates that the `pr-no-qa-bypass` job rejects a PR body containing
`QA-Waiver:` without a paired `Duong-Sign-Off: <iso8601>` line. This is the exact
pattern from PR #59 (`chore: xfail test skeletons — dashboard Phase 1`, merged
2026-04-25) that shipped a false waiver.

**False-waiver line in PR body (verbatim from PR #59):**
```
QA-Waiver: non-UI tools/retro pipeline only — no browser rendering. Akali Playwright flow not applicable.
```

**CI result:** FAIL — `QA verification marker (Rule 16 amended — D6)` job rejected

**Failing job URL:** https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24985406840/job/73157313221

**Head commit SHA:** 440a47e8 (fixture/qa-waiver-regression-head)

**Base branch:** fixture/qa-waiver-regression-base (tracks qa-enforcement-phase-a @ ff89c0e7)

**Status:** Open, do NOT merge or close — permanent regression reference.

## Notes

- The `pr-no-qa-bypass` job is the rejecting check (job name: "QA verification marker (Rule 16 amended — D6)")
- The `QA gate check (Rule 16)` job (old Rule 16 UI-flow gate) PASSED because the PR has no UI file paths — confirming the old gate was blind to this waiver pattern
- This demonstrates the gap closed by T.QA.8/T.QA.9: the old gate only checked UI PRs; the new gate checks ALL PRs for waiver discipline
