---
status: proposed
project: agent-network-v1
concern: personal
owner: swain
created: 2026-04-27
last_reviewed: 2026-04-27
priority: P2
qa_plan: none
qa_plan_none_justification: "This ADR delegates QA to a downstream implementation plan."
---

# Fixture F — qa_plan: none with justification but missing downstream_plan: path (REJECT)

## Context

This fixture exercises D5 Surface 1 case (f): frontmatter has both `qa_plan: none`
and `qa_plan_none_justification:`, but the justification string does not include a
`downstream_plan: <path>` field pointing at a real plan. Per OQ #4 pick (a), the
linter must validate that the justification includes a downstream plan path and that
the path resolves to `proposed/`, `approved/`, or `in-progress/`.

## Decision

Some decision text. Advisory ADR, but the justification is prose-only without naming
which implementation plan owns the actual QA contract.

## Tasks

- T1: Do a thing
