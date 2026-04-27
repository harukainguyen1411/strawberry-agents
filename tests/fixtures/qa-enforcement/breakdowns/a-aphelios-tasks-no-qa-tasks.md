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

# Fixture A — Aphelios adds ## Tasks without ### QA Tasks (REJECT)

## Context

This fixture exercises D5 Surface 2 case (a): the breakdown agent (Aphelios) commits
an amendment that adds a `## Tasks` section but omits the required `### QA Tasks`
subsection. The breakdown-qa-tasks linter must reject when `STRAWBERRY_AGENT=aphelios`.

## Decision

Some decision. Breakdown required.

## QA Plan

**UI involvement:** no

- Output surface: stdout

## Tasks

- T1: Implement the hook
  owner: viktor
  est_minutes: 50
- T2: Wire hook into pre-commit chain
  owner: viktor
  est_minutes: 20
