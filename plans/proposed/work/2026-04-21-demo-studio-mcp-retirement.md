---
status: proposed
complexity: simple
concern: work
owner: Heimerdinger
created: 2026-04-21
tags:
  - demo-studio
  - mcp
  - cloud-run
  - teardown
  - work
tests_required: false
---

# Plan: Retire TS demo-studio-mcp Cloud Run service

## Goal

Tear down the TypeScript `demo-studio-mcp` Cloud Run service and its associated
infrastructure (image registry, service account, secret bindings) now that the
in-process MCP sub-app in S1 is live and the cutover to `MANAGED_AGENT_MCP_INPROCESS=true`
has been verified on both staging and production.

## Context

The `demo-studio-mcp` TS service is currently 503 (image registry project deleted).
It is retained as a rollback surface for the MCP in-process migration
(plan: `2026-04-21-mcp-inprocess-merge`). Formal teardown must not proceed until
the in-process migration is confirmed stable in production for at least 7 days.

## Gate

- In-process MCP live in production for >= 7 days with no rollbacks
- Heimerdinger sign-off on smoke data

## Tasks

- [ ] Confirm in-process MCP stable for 7 days in production (no rollbacks, clean smoke logs) | estimate_minutes: 5
- [ ] Heimerdinger sign-off on smoke data | estimate_minutes: 15
- [ ] Delete Cloud Run service `demo-studio-mcp` and associated service account | estimate_minutes: 20
- [ ] Remove secret bindings for `DS_STUDIO_MCP_TOKEN` that pointed to the TS service | estimate_minutes: 10
- [ ] Update `docs/cloud-run-config-snapshot.md` to mark service as retired <!-- orianna: ok --> | estimate_minutes: 5

## Out of scope

Source code deletion from the GitHub repo is tracked separately.
