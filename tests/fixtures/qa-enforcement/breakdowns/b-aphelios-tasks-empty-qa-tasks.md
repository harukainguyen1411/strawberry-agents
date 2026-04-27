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

# Fixture B — Aphelios adds ## Tasks with empty ### QA Tasks heading (REJECT)

## Context

This fixture exercises D5 Surface 2 case (b): Aphelios adds a `## Tasks` section
that includes a `### QA Tasks` heading, but the heading has no task lines beneath it.
An empty `### QA Tasks` (heading-only, no `-` or `*` task lines) must be rejected.

## Decision

Some decision. Breakdown required.

## QA Plan

**UI involvement:** no

- Output surface: files only

## Tasks

- T1: Implement the hook
  owner: viktor
  est_minutes: 50

### QA Tasks

