---
status: approved
project: agent-network-v1
concern: personal
owner: evelynn
created: 2026-01-10
last_reviewed: 2026-01-10
priority: P1
---

# Fixture I — pre-existing approved plan without §QA Plan (ACCEPT when status-M)

This fixture represents an approved plan that predates the §QA Plan requirement
(ADR §OQ#7(b) forward-only enforcement). It has no `qa_plan:` frontmatter field
and no `## QA Plan` section.

When committed as a status-M modification (existing file), the linter MUST accept
it (grandfathered). When committed as status-A (new file), it MUST reject.

## Context

Pre-existing plan content here.

## Decision

Some architectural decision made before the QA enforcement ADR was written.

## Tasks

- T1: some task
  owner: viktor
