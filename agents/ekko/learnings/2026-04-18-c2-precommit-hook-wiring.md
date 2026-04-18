---
date: 2026-04-18
topic: C2 pre-commit hook wiring — CWD-relative require() bug and pnpm/npm confusion
---

# C2 Hook Wiring — Session Learnings

## What happened

Two PRs were opened for C2 (pre-commit hook wiring for dashboards):

- **#161** (chore/c2-dashboards-hook-wiring): verify-only approach — the existing hook already picks up any package with `tdd.enabled:true` generically; no code changes needed. Adds C2 verification section to `test-hooks.sh`. This is the canonical PR.
- **#165** (chore/c2-precommit-dashboards): attempted to add explicit `pnpm -C` wiring. Jhin flagged CWD-relative `require()` bug (R22). Fix was implemented (absolute path via `$REPO_ROOT/$pkg_json`). But the whole PR was ultimately closed as superseded — the `pnpm -C` approach would break on machines without pnpm (repo uses npm workspaces).

## Key lessons

### 1. Verify the package manager before writing hook code
The repo uses npm workspaces (`package-lock.json` present, no `pnpm-lock.yaml`, pnpm not installed). The task description said "pnpm -C" but the actual repo uses npm. Always check before writing package-manager-specific code.

### 2. CWD-relative `require()` is a real bug in git hooks
`require('./$path')` resolves relative to CWD, not the script file. Git can invoke hooks with CWD set to a subdirectory (e.g. `cd dashboards/server && git commit`). Fix: always anchor to `git rev-parse --show-toplevel` — `require('$REPO_ROOT/$path')` using shell interpolation (not `process.env`).

### 3. Drop grep fallbacks for node — fail-hard is cleaner
The fragile grep fallback for multiline JSON (`grep '"tdd"' ... | grep '"enabled".*true'`) is unreliable after prettier reformats. Node is required on any machine doing TDD-gated commits. Fail-hard is correct.

### 4. Verify-only is often the right answer for "wiring" tasks
If the hook already does generic detection, the correct deliverable is tests proving it works — not new code paths. Check the existing implementation before writing new branches.
