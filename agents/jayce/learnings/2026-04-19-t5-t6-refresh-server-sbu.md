# 2026-04-19 — T5 refresh-server.mjs + T6 sbu.sh

## Session context

Built T5 (refresh-server.mjs) and T6 (sbu.sh CLI alias) back-to-back for the Claude Usage Dashboard.
Both tasks operated in `harukainguyen1411/strawberry-app` with worktrees.

## Key learnings

### 1. `await` inside non-async functions fails at parse time
Writing `const http = await import('node:http')` inside a regular (non-async) function is a
SyntaxError at parse time, not runtime. Always import at the module top level for ESM.

### 2. xfail test pattern with `{ todo: '...' }` in node:test
- Use `{ todo: 'reason' }` as the second argument to `test()` — this marks it as todo (expected-to-fail).
- The test runner shows these as `✖ ... # reason` and counts them in `todo`, not `fail`.
- Tests pass exit 0 (no hard failures) so the commit is clean.
- In the impl commit, strip the `todo` key (change `{ todo: '...' }` to `{}`) to flip them live.

### 3. Port collision avoidance in HTTP server tests
When running multiple server tests in the same file, use staggered fixed ports
(e.g. BASE_PORT, BASE_PORT+1, BASE_PORT+2, BASE_PORT+3) rather than random ports.
This avoids TOCTOU races while remaining deterministic.

### 4. T5 server: `isLocalOrigin` must handle absent Origin header
When there's no `Origin` header (direct non-browser call, e.g. from node test via `http.request`),
we should allow the request. Only deny when Origin is present and non-local.

### 5. T6 PID guard: stale PID file cleanup
`kill -0 $PID` checks if a process is alive without sending a signal. If the PID is stale
(process already dead), remove the stale file before proceeding with server startup.

### 6. Remote vs local main divergence
The local `main` branch in strawberry-app was behind `origin/main` (was at T7 merge, not T4 merge).
Always do `git fetch origin` and branch off `origin/main` explicitly when creating worktrees
for new feature branches, not from the local tracking branch.

Pattern: `git worktree add /tmp/path -b branch-name origin/main`

### 7. Env var overrides in POSIX shell scripts for testability
Pass all path dependencies (BUILD_SH, REFRESH_SERVER_MJS, PID_FILE, REPO_ROOT) as env vars
with sensible defaults. This allows test harnesses to inject shims without modifying the script.
