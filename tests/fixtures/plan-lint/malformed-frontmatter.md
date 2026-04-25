---
status: proposed
concern: personal
owner: seraphine
created: 2026-04-25
tags: [frontend
  this: is: broken: yaml
---

# UI Feature: Broken plan

## Context

This plan has malformed YAML frontmatter (unclosed array, duplicate colons).
The linter must handle this gracefully — parse error, not crash.

## Tasks

- [ ] **T1** — Do a thing. Files: `apps/web/src/components/Broken.vue`.
