---
status: proposed
concern: personal
owner: seraphine
created: 2026-04-25
tests_required: false
complexity: normal
tags: [frontend, ui-ux]
UX-Waiver: pure refactor — no visible delta; existing Widget component renamed only, no new states or routes introduced
---

# UI Refactor: Rename Widget component

## Context

Rename `Widget.vue` to `DashboardWidget.vue` for naming consistency.
No visual change, no new states, no route changes.

## Decision

Rename the file and update all import references.

## Tasks

- [ ] **T1** — Rename Widget.vue. Files: `apps/web/src/components/DashboardWidget.vue`.
- [ ] **T2** — Update imports. Files: `apps/web/src/pages/Dashboard.vue`.

## Test plan

No test changes required — rename only.
