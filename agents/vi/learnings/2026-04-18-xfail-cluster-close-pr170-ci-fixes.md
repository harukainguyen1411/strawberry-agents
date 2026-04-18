---
date: 2026-04-18
topic: xfail-cluster-close-pr170-ci-fixes
---

# Session learnings — xfail cluster close-out + #170 CI fixes

## Stale worktree reads cause false "already clean" reports

When multiple agents push to the same branch in parallel, a local worktree can be
several commits behind origin. `git fetch origin` + verify before reporting status.
Reported F1/F2 xfails as "already test.fails" when Viktor had already converted them
to plain `test()`. Always fetch before asserting branch state.

## unit-tests.yml was missing npm install before npm run test:unit

CI failure "vitest: not found" — the workflow ran `npm run test:unit` without a prior
`npm install`. Fix: `npm install --prefer-offline && npm run test:unit --if-present`
in the per-package loop. This is a one-time fix on main; affects every TDD-enabled
package CI run.

## PR body QA-Waiver required even for non-UI test-only PRs

PR body linter requires `QA-Waiver: non-UI (...)` line for non-UI PRs. Without it CI
fails the body-lint check. Add it at PR creation time, not as a fix.

## Merge conflict in firestore-rules.xfail.test.ts — always take main's version

Branch had simpler throwing-body version; main had richer emulator assertion version.
Main is authoritative for shared test fixtures. Use `git checkout --theirs` for
conflicts in shared test files when main's version is strictly more capable.

## package-lock.json conflicts: checkout --theirs then npm install

When deps differ between branches (e.g. `@google-cloud/storage` on feature vs
`firebase-admin` on main), take `--theirs` for the lockfile then run `npm install`
to regenerate it with both deps. Don't manually merge lockfiles.
