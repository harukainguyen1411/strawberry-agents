---
status: approved
concern: personal
owner: seraphine
created: 2026-04-25
complexity: standard
UX-Waiver: pure refactor — no visible delta; only extracting shared utility from existing component
---

# Test fixture: UI plan with UX-Waiver frontmatter

## Context

Fixture for uxspec-gate hook tests. Represents a UI-touching plan that
has a `UX-Waiver:` line in frontmatter in lieu of §UX Spec.
The waiver is valid per D2: pure refactor with no visible delta.

## Decision

Refactor `Button.vue` to extract shared click-handler utility.
No visual changes.

## Tasks

- [ ] T-1 — refactor `apps/frontend/src/components/Button.vue` to extract utility. estimate_minutes: 20.
