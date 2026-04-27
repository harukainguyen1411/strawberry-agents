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

# Fixture C — ## QA Plan body populated but missing **UI involvement:** line (REJECT)

## Context

This fixture exercises D5 Surface 1 case (c): `## QA Plan` has non-empty body but
is missing the `**UI involvement:** yes|no` routing line. The linter must reject
citing the missing UI-involvement declaration.

## Decision

Some decision text.

## QA Plan

This plan has some QA notes but never declares whether UI is involved. It describes
output surfaces and acceptance criteria but skips the required routing declaration.

- Output surface: stdout logs
- Edge cases: timeout, empty input

## Tasks

- T1: Do a thing
