---
task: T.QA.17
date: 2026-04-27
satisfies: ADR T-QA1 (regression PR fixture cross-reference)
plan: plans/approved/personal/2026-04-27-qa-enforcement-and-breakdown-discipline.md
---

# T.QA.17 — Self-loop: regression PR fixture cross-reference (ADR T-QA1)

## Purpose

ADR T-QA1 states: "Verify the regression-test commitment for the PR #59 false-waiver case is
present in the downstream breakdown (Aphelios) — at minimum, a fixture PR-body that asserts the
new pr-lint job rejects `QA-Waiver: non-UI ...` without `Duong-Sign-Off:`."

T.QA.10 fulfilled this by opening a real fixture PR on the repository. This file cross-references
those artifacts for the implementation PR's `QA-Verification:` marker.

## T.QA.10 fixture PR record

**PR URL:** https://github.com/harukainguyen1411/strawberry-agents/pull/107

**Failing CI job URL:** https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24985406840/job/73157313221

**Head fixture commit SHA:** `440a47e8`

**What it demonstrates:**
- A PR body containing `QA-Waiver: non-UI tools/retro pipeline only — no browser rendering. Akali Playwright flow not applicable.` (verbatim from PR #59)
- WITHOUT a paired `Duong-Sign-Off: <iso8601>` line
- Triggers the `pr-no-qa-bypass` job to FAIL with exit 1

This is the exact PR #59 false-waiver pattern described in the ADR §Context as the root-cause
incident. The regression fixture confirms the new gate catches it.

## ADR T-QA1 status

ADR T-QA1 is satisfied:
- The fixture PR (#107) is present and permanently open as a regression reference
- The failing CI job URL confirms the `pr-no-qa-bypass` job rejects the false-waiver pattern
- The head commit SHA (`440a47e8`) is recorded for traceability
- Full detail in `tests/qa-enforcement/fixture-prs.md`
