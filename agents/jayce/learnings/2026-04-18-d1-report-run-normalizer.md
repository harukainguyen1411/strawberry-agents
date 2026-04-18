# D1 report-run.sh session learnings — 2026-04-18

## What was built
`scripts/report-run.sh` — POSIX-portable bash normalizer for Vitest/Playwright JSON → `POST /api/runs` ingestion shape. Already implemented on the branch; work this session was verifying acceptance criteria, flipping bats xfail skip markers, and applying two follow-up fixes.

## Key learnings

### 1. Check for prior work on the branch before implementing
The implementation commit (fab490b) was already on `chore/d1-report-run` from a prior session. Pattern: always `git log --oneline origin/main..HEAD` first on an existing worktree before writing new code.

### 2. it.failing is Playwright; it.fails is Vitest 4.x
`it.failing(...)` throws `TypeError: it.failing is not a function` in Vitest 4.x — zero tests register, file silently passes. The correct Vitest API is `it.fails(...)`. Always verify xfail files appear in the test count (`npx vitest run --reporter=verbose`) before committing — if the count doesn't include them, the file isn't parsing.

Two files on the D1 branch had this (`health.xfail.test.ts`, `firestore-rules.xfail.test.ts`) — caught and fixed in b377dd6.

### 3. Client-side IDs for server-owned entities are dead code
D1 was generating `case_${Date.now()}_random` IDs client-side. D2 server assigns ULIDs and overwrites. Strip any client-generated IDs for entities the server owns — they're noise and can cause confusion about which ID is authoritative.

### 4. bats xfail pattern: DASHBOARD_URL override inline, not from setup()
The bats setup() exported `DASHBOARD_URL` globally, but each test overrides it inline. This is cleaner for tests that need different mock behavior (hung listener vs. no listener). Prefer inline env overrides in bats tests.
