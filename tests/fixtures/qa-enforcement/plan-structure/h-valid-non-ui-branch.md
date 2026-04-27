---
status: proposed
project: agent-network-v1
concern: personal
owner: swain
created: 2026-04-27
last_reviewed: 2026-04-27
priority: P2
qa_plan: required
---

# Fixture H — populated non-UI-branch §QA Plan (ACCEPT)

## Context

This fixture exercises D5 Surface 1 case (h): a fully valid plan with a populated
non-UI-branch `## QA Plan` section. The linter must accept this plan.

## Decision

Some decision text for a non-UI deliverable (shell scripts, JSON outputs, CI hooks).

## QA Plan

**UI involvement:** no

- Output surface: stdout / exit codes consumed by pre-commit hook chain
- Real-data acceptance gate: bash scripts/hooks/pre-commit-zz-plan-structure.sh
  --fixture-path tests/fixtures/qa-enforcement/plan-structure/g-valid-ui-branch.md
  --staged-path plans/proposed/test.md; assert exit 0
- Fixture-vs-real split: fixture tests in tests/fixtures/qa-enforcement/; real-data
  runs against live staged plans in CI
- Edge cases covered: missing heading, empty body, invalid UI-involvement value,
  qa_plan:none without justification
- Manual verification: coordinator runs fixture suite before flipping DoD checkboxes
- xfail tests: tests/qa-enforcement/test_plan_structure_qaplan.sh
- PR marker QA-Verification: ran fixture suite; all cases behaved as expected

## Tasks

- T1: Extend the plan-structure linter
  owner: viktor
  est_minutes: 50
