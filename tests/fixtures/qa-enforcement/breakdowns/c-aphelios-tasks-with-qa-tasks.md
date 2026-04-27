---
status: proposed
project: agent-network-v1
concern: personal
owner: aphelios
created: 2026-04-27
last_reviewed: 2026-04-27
priority: P2
qa_plan: required
---

# Fixture C — Aphelios adds ## Tasks with populated ### QA Tasks (ACCEPT)

## Context

This fixture exercises D5 Surface 2 case (c): Aphelios adds a `## Tasks` section
that includes a `### QA Tasks` subsection with at least one task line. The
breakdown-qa-tasks linter must accept this commit under `STRAWBERRY_AGENT=aphelios`.

## Decision

Some decision. Breakdown required.

## QA Plan

**UI involvement:** no

- Output surface: stdout / exit codes

## Tasks

- T1: Implement the hook
  owner: viktor
  est_minutes: 50
- T2: Wire hook into pre-commit chain
  owner: viktor
  est_minutes: 20

### QA Tasks

- T-QA1: Real-data acceptance — run hook against fixture plans; assert reject cases
  exit non-zero and accept cases exit zero
  owner: implementer
  est_minutes: 15
  success: all eight fixture cases behave as expected
