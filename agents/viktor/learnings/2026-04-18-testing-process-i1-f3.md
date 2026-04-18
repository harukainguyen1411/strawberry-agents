---
date: 2026-04-18
topic: testing-process team — I1 deploy script + F3 CORS middleware
---

## I1 — scripts/deploy/dashboards.sh

- Worktree already had xfail + implementation commits from a prior session. Bats tests were 1/6 on arrival.
- Two bugs fixed:
  1. `cp -r dist/.` fails when mock pnpm produces no dist/ — guard with `[ -d dist ]`.
  2. Cross-file line comparison in bats test 6 (`pnpm.calls` line 1 vs `docker.calls` line 1 — `1 -lt 1` is always false). Fixed by adding a shared `calls.log` to both stubs.
- Root `package-lock.json` was missing firebase-admin@13.8.0 workspace entries — CI failed on `npm ci`. Fix: `npm install --package-lock-only` from repo root in the worktree.
- Always run bats tests immediately on arrival to a worktree that claims implementation is done.

## F3 — CORS middleware

- ADR §7 CORS policy: UI origin allowed on GET/PATCH/HEAD; ingestion routes (POST /api/runs, /finalize) are server-to-server only — deny CORS preflight.
- Key design trap: `GET /api/runs` is a READ endpoint that browsers access; path-prefix matching on `/api/runs` would wrongly block it. Must scope ingestion denial to POST+OPTIONS by method, not path alone.
- Vitest unit tests using mock req/res objects work well for pure middleware — no supertest needed.
- `it.fails` (Vitest) NOT `it.failing` (Playwright) — confirmed again this session.
