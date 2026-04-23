---
status: proposed
concern: personal
owner: karma
created: 2026-04-22
complexity: quick
tests_required: false
tags: [hooks, git, enforcement, agents]
related:
  - plans/in-progress/personal/2026-04-21-staged-scope-guard-hook.md
  - scripts/hooks/pre-commit-staged-scope-guard.sh
---

# Agent staged-scope adoption — teach the fleet to set STAGED_SCOPE

## Context

`scripts/hooks/pre-commit-staged-scope-guard.sh` was added by
`plans/in-progress/personal/2026-04-21-staged-scope-guard-hook.md` and delivers
enforcement. The hook is deliberately non-blocking when `STAGED_SCOPE` is unset —
it only warns on bulk commits — to allow a gradual agent migration.

This plan delivers the adoption sweep: update agent definitions for Yuumi, Ekko,
Syndra, Talon, Viktor, and Jayce to set `STAGED_SCOPE` (newline-separated staged
paths) immediately before each `git commit` call, and to use `STAGED_SCOPE='*'`
for acknowledged bulk operations such as memory consolidation and install-hooks.sh
re-runs.

Once all executors are updated, the warning-only mode becomes a backstop for
unanticipated cases rather than the normal path.

> **Sequencing:** land this after PR #30 (orianna-gate-simplification) merges, to avoid conflicts on Ekko's and Yuumi's agent definitions which PR #30 also edits.

## Tasks

1. **Update executor agent definitions** — `kind: chore`, `estimate_minutes: 30`. Update agent definitions for Yuumi, Ekko, Syndra, Talon, Viktor, and Jayce to set `STAGED_SCOPE` before each `git commit` call. Use `STAGED_SCOPE='*'` for acknowledged bulk operations (memory consolidation, install-hooks.sh re-runs). <!-- orianna: ok -- agent-def paths exist at plan authoring time -->
   - Use newline-separated paths for multi-file commits (not space-separated). Example: `STAGED_SCOPE=$(printf 'a/b.md\nc/d.md')`. The guard hook parses newlines; space-separated paths silently fail validation.
