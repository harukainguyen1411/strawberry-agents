---
date: 2026-04-18
topic: I1 deploy script — dashboards.sh + bats test fixes
---

## What happened

Task I1: implement `scripts/deploy/dashboards.sh` to build the test-dashboard frontend, assemble server public/ assets, build + push a Docker image to Artifact Registry, deploy to Cloud Run, and emit a `logs/deploy-audit.jsonl` entry.

The worktree `i1-deploy-dashboards` already had both the xfail bats commit and an implementation commit from a prior session. The bats tests were failing at test start (5/6 failing) due to two bugs:

1. **Missing dist/ guard**: `cp -r dist/.` fails when mock pnpm doesn't create dist/. Fixed with an `if [ -d ... ]` guard.
2. **Cross-file line comparison**: test 6 compared line numbers from `pnpm.calls` vs `docker.calls` (always both "1", so `1 -lt 1` = false). Fixed by adding a shared `calls.log` to both stubs and using that for ordering verification.

## Lessons

- Bats stub scripts use single-quoted heredocs, so `$MOCK_DIR` expands at runtime (not at creation time) — ordering checks across separate per-tool log files don't work; use a shared chronological log.
- When an implementation commit exists but tests fail, always run the tests first before assuming the work is complete.
- The `cp -r src/.` idiom fails if `src/` doesn't exist — always guard with `[ -d src ]`.
