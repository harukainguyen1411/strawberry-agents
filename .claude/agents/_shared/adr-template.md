---
# ADR frontmatter stub — copy into your plan file and fill in all fields.
# status: proposed
# project: <project-slug>
# concern: personal | work
# owner: <agent-name>
# created: YYYY-MM-DD
# last_reviewed: YYYY-MM-DD
# priority: P0 | P1 | P2
# tests_required: true | false
# complexity: standard | complex
# qa_plan: required  # or 'none' with qa_plan_none_justification: <prose + downstream_plan: plans/...>
# Figma-Ref: # optional — required only for design-comparison gating per ADR OQ #5 opt-in
# tags: []
# related: []
---

# <Title> — <one-line purpose>

## Context

<!-- What situation or incident motivated this ADR? What was tried, what failed, what invariant was violated? -->

## Architecture impact

<!-- Table of surfaces changed: file | change description -->

| Surface | Change |
|---------|--------|
|  |  |

## Decision

<!-- Named decisions D1, D2, … Each decision answers one question and names the pick + rationale. -->

### D1 — <Decision title>

<!-- Pick: **<option>** — <rationale> -->

## Tasks

<!-- Breakdown by Aphelios/Kayn. Phases A, B, C … with explicit phase gates. -->

<!-- IMPORTANT: Every ## Tasks section MUST contain a ### QA Tasks subsection (Rule in aphelios.md / kayn.md Hard Rules, enforced by pre-commit-breakdown-qa-tasks.sh). -->

### QA Tasks

<!-- Convert the ## QA Plan below into concrete enumerated tasks. For UI deliverables: Akali Playwright flows, screenshot capture points, observation-narrative requirement, PR marker. For non-UI deliverables: real-data acceptance gate, fixture-vs-real split, manual verification, xfail tests, QA-Verification PR marker. -->

- T-QA1: <!-- describe the QA task -->
  owner: <!-- akali | implementer | coordinator -->
  estimate_minutes: <!-- int -->
  success: <!-- pass/fail criterion -->

## Test plan

<!-- High-level test surface; detailed xfail tests live in Phase A of the breakdown. -->

## QA Plan

**UI involvement:** yes | no

<!-- Select ONE branch below and delete the other. -->

<!-- === UI BRANCH (delete if UI involvement: no) ===
**If yes:**
- Surfaces in scope: <list of routes / pages / artifacts>
- Playwright flows: <list of user-stories Akali will exercise>
- Screenshot capture points: <enumerated meaningful moments — e.g. route entry, post-action, error state, final state>
- Per-screenshot observation contract: each screenshot in the QA report carries a "what was checked, observed vs expected, pass/fail" line. Screenshots-as-receipts disallowed.
- Success threshold: <pass/fail criteria; what counts as PARTIAL>
- Figma-Ref (optional): <Figma frame ID or wireframe path; omit row entirely if no opt-in>
- Akali invocation pre-PR; report at `assessments/qa-reports/<slug>.md`; PR marker `QA-Report:` (and `Visual-Diff:` only when Figma-Ref is in scope)
=== END UI BRANCH === -->

<!-- === NON-UI BRANCH (delete if UI involvement: yes) ===
**If no:**
- Output surface: <stdout / files / API / logs>
- Real-data acceptance gate: <command(s) that must pass against real inputs, not just fixtures>
- Fixture-vs-real split: <which tests fixture-only, which against real>
- Edge cases covered: <list>
- Manual verification: <coordinator steps before flipping DoD checkboxes>
- xfail tests: <test files / IDs>
- PR marker `QA-Verification: <commands>` citing the verification run
=== END NON-UI BRANCH === -->

## Open Questions

<!-- OQ-1, OQ-2 … Each question names the options (a/b/c) and the pick. Resolve before breakdown dispatch. -->

## References

<!-- Links to related plans, CLAUDE.md rules, prior incidents. -->
