---
status: approved
concern: personal
owner: aphelios
created: 2026-04-25
complexity: standard
---

# Test fixture: Non-UI plan (no §UX Spec required)

## Context

Fixture for uxspec-gate hook tests. Represents a backend-only / infra plan
that touches NO UI surface. No §UX Spec is required.

## Decision

Add a new database migration and API endpoint.

## Tasks

- [ ] T-1 — implement `apps/api/src/routes/health.ts`. estimate_minutes: 20.
- [ ] T-2 — add database migration `apps/api/migrations/001_add_health_table.sql`. estimate_minutes: 10.
- [ ] T-3 — update `scripts/hooks/pre-commit-unit-tests.sh`. estimate_minutes: 5.
