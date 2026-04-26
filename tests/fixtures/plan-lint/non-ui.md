---
status: proposed
concern: personal
owner: ekko
created: 2026-04-25
tests_required: true
complexity: normal
tags: [infra, ci]
---

# CI: Add deployment smoke test retry logic

## Context

Post-deploy smoke tests occasionally fail due to cold-start latency.
Add configurable retry count to the smoke test runner.

## Decision

Extend `scripts/deploy/rollback.sh` with a retry loop before triggering rollback.

## Tasks

- [ ] **T1** — Add retry loop. Files: `scripts/deploy/rollback.sh`.
- [ ] **T2** — Add env var `SMOKE_RETRY_COUNT`. Files: `.github/workflows/deploy.yml`.

## Test plan

Shell tests asserting retry behaviour.
