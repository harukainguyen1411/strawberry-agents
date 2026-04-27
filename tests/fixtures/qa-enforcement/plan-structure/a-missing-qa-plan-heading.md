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

# Fixture A — missing ## QA Plan heading (REJECT)

## Context

This fixture exercises D5 Surface 1 case (a): a plan in `plans/proposed/` that has
`qa_plan: required` in frontmatter but no `## QA Plan` section in the body. The
plan-structure linter must reject it with a message citing the missing heading.

## Decision

Some decision text. Valid structure aside from the missing QA Plan section.

## Tasks

- T1: Do a thing
