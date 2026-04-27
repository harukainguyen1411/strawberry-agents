---
status: proposed
project: agent-network-v1
concern: personal
owner: swain
created: 2026-04-27
last_reviewed: 2026-04-27
priority: P2
qa_plan: none
---

# Fixture E — qa_plan: none without qa_plan_none_justification (REJECT)

## Context

This fixture exercises D5 Surface 1 case (e): frontmatter has `qa_plan: none` but
is missing the required `qa_plan_none_justification:` companion field. Per OQ #4 pick
(a), both fields are required together. The linter must reject.

## Decision

Some decision text. Advisory ADR that delegates QA to a downstream plan, but fails
to name which downstream plan owns the QA contract.

## Tasks

- T1: Do a thing
