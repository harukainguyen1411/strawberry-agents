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

# Fixture G — populated UI-branch §QA Plan (ACCEPT)

## Context

This fixture exercises D5 Surface 1 case (g): a fully valid plan with a populated
UI-branch `## QA Plan` section. The linter must accept this plan.

## Decision

Some decision text for a UI-involving deliverable.

## QA Plan

**UI involvement:** yes

- Surfaces in scope: /dashboard route, static HTML output
- Playwright flows: login → view chart → click filter
- Screenshot capture points: route-entry, post-filter-click, final state
- Per-screenshot observation contract: each screenshot in the QA report carries a
  "what was checked, observed vs expected, pass/fail" line
- Success threshold: all three screenshots have passing observation lines; report
  reads as a narrative
- Akali invocation pre-PR; report at assessments/qa-reports/fixture-g.md; PR
  marker QA-Report:

## Tasks

- T1: Implement the dashboard route
  owner: viktor
  est_minutes: 60
