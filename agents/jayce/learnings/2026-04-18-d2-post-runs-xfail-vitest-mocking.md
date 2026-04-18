# 2026-04-18 D2 POST /api/runs — xfail mechanics and Vitest mocking

## What I built
`POST /api/v1/runs` handler: validates run type, writes Run+Case docs in a Firestore batch, generates V4 signed upload URLs per artifact ref, returns `{run_id, artifact_upload_urls}`.

## Key learnings

### 1. `it.failing` is Playwright API; Vitest uses `it.fails`
All xfail seeds in this codebase were written with `it.failing(...)` which is Playwright's API and not valid in Vitest 4.x. The correct Vitest syntax is `it.fails("...", () => { throw new Error(...) })`. Every xfail file hitting this cluster must use `it.fails` with a throwing body.

### 2. Vitest `vi.mock` + `INGEST_TOKEN` env approach
For testing Express handlers that use real middleware (not mocked), the simplest pattern is:
- Set `process.env.INGEST_TOKEN = TEST_TOKEN` in `beforeAll`
- Use that same `TEST_TOKEN` in the request `Authorization` header
- This avoids `vi.mock` complexity with ES module mocking and `.js` extensions

### 3. Cross-worktree dependency management
When an implementation depends on modules in other open PRs (F1/F2 auth, B3 signed URLs), copy the source files into the branch rather than leaving imports to unresolved paths. The PR description documents which upstream PRs they originate from so they can be cleaned up on merge.

### 4. Main branch had staged cross-agent changes
At session start, main had staged changes from other agent sessions (jhin memory, ekko test-hooks.sh, package-locks). The pre-commit hook blocked commit due to `it.failing` in `firestore-rules.xfail.test.ts` and `health.xfail.test.ts`. Had to fix the syntax before committing the cross-agent cleanup.

### 5. Worktree sync flow
Pattern: `git worktree add .worktrees/<name> -b <branch>` → `git -C .worktrees/<name> merge main --no-edit` to get latest before starting work. When worktree already exists on an older commit, merge main first.
