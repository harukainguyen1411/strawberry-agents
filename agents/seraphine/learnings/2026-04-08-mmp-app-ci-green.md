# 2026-04-08 — Greening mmp-app PR #1098 CI

Paired with Zilean to get PR #1098 (`duong.nguyen/mmp-claim-ui-bugfix-improvements`) CI fully green. Frontend side. Several non-obvious gotchas worth capturing.

## Gotchas

### 1. `.npmrc` lived only on Duong's laptop
`.npmrc` containing `legacy-peer-deps=true` existed locally but was never `git add`ed. It's not in `.gitignore`, just untracked. The Dockerfile had `COPY .npmrc .` (added in 5d904ceb), so CI Docker builds failed with `"/.npmrc": not found`, and GitHub Actions `test` job failed `npm ci` because the peer-deps conflict (pinia>=2.2.6 vs vue@3.3.4 — pinia 2.2.8 peer requires vue>=3.5.11) can only be bypassed with legacy-peer-deps. Fix: commit `.npmrc` (f8204cd0). **Always check `git status` for untracked config files that Dockerfiles reference.**

### 2. `token-ui.Dockerfile` is a separate Dockerfile
mmp-app has two Dockerfiles: `Dockerfile` (main) and `token-ui.Dockerfile` (companion image). Any fix to one that touches `COPY .npmrc` must be mirrored in the other. Easy to miss.

### 3. `vitest.workspace.ts` silently runs a Playwright browser suite
`vitest.workspace.ts` defined two projects: `unit` (jsdom) and `storybook` (browser mode, Playwright chromium). Both `extends: 'vite.config.ts'`, so both inherit `server.host: 'local.dev.missmp.tech'`. The storybook project tries to open a chromium browser pointed at that host in CI, which fails DNS resolution and hangs the vitest main process for 10s before erroring with `close timed out after 10000ms`. The hang message is extremely misleading — it looks like a coverage/MSW issue.

**Fix:** scope the CI script to one project: `vitest run --project=unit --pool=forks`. The browser suite needs its own dedicated job (with browsers installed and a stub vite server) if it's ever going to run.

### 4. `vite.config.ts` `fs.readFileSync` at top level crashes vitest
Unconditional `fs.readFileSync('./.cert/key.pem')` ran at config-load time and crashed vitest in CI where the cert doesn't exist. Wrapped in `fs.existsSync` guard. Vite dev server still gets certs when they're present.

### 5. Pre-commit husky hook auto-stages other modified files
After `git add X` and `git commit`, the husky hook ran `lint --fix` which re-staged a co-worker's uncommitted workflow edits. Committed them by accident. Caught via `git show HEAD --stat`, `git reset --soft HEAD~1`, unstaged co-worker's files, re-committed with `git commit --only <path>`. **When pairing on a branch, always `git show HEAD --stat` after commit to verify scope — or use `git commit --only <path>` proactively.**

### 6. Pre-commit hook reformats test setup files after discarded edits
`src/test/setup.ts` kept showing as modified every time (hook rewriting import order + semicolons). Ignoring the working-tree churn is fine; just don't let the reformat trigger when you're trying to keep clean commits.

## Process notes

- Pairing with a teammate on the same branch is risky. Husky hooks can sweep in their WIP. Use `git commit --only` or stage explicitly and verify scope.
- `gh pr checks <num> --watch` is your friend — one command that blocks until CI resolves.
- When chasing "close timed out" in vitest, don't chase MSW/coverage first. Check `vitest.workspace.ts` for a browser project, and check config imports for side-effecty `fs` / network calls.
