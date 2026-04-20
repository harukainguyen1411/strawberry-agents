# company-os untracked-vs-feat/demo-studio-v3 diff report

**Date:** 2026-04-20
**Task:** Read-only triage of untracked files on chore/tdd-gate-clean vs feat/demo-studio-v3

## Key findings

- `tools/demo-studio-v3/` local directory contains ONLY runtime artifacts (.env,
  .agent-ids.env, .prior-mcp-url) and pycache. No source files are untracked locally —
  the service source exists only on feat/demo-studio-v3. These 3 local files are
  LOCAL-ONLY (no collision) and must be preserved for service operation.
- `tools/demo-studio-mcp/` same pattern: local has .env, .deploy-url, dist/ JS — all
  LOCAL-ONLY runtime artifacts. No source collisions.
- Most plan files are IDENTICAL to target. Only `plans/2026-04-09-demo-agent-system.md`
  differs (target is v2 at 694 lines; local is v1 at 775 lines — local has MORE content
  in some sections but lacks v2 flow diagram additions).
- `tools/demo-factory/` has 9 source files that DIFFER — all are local-has-older-version
  cases (target has more features). Local also has `tools/demo-factory/.env` (LOCAL-ONLY,
  real secrets — must not be deleted).
- `tools/slack-triage/main.py` DIFFERS significantly (target 749 lines, local 369 lines —
  target has full spec-gathering state machine, HubSpot integration, Demo Studio v2 flag).

## Technique note

When git refuses to checkout due to untracked collision set, use `find + sha256sum` per
file against `git show <branch>:<path> | sha256sum` to triage before any destructive action.
pycache and .pytest_cache dirs are always LOCAL-ONLY — safe to remove without concern.
