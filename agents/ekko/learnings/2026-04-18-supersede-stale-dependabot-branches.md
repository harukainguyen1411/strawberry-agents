# Superseding stale dependabot branches via combined PR

## Problem

Dependabot branches are cut at the moment the PR opens. If main has moved forward (e.g. other batches landed vite/vitest bumps), the dependabot branch can carry OUTDATED co-changes to `package.json` that would downgrade already-bumped deps on merge.

Example from 2026-04-18: dependabot PR #47 (lint-staged 16.2→16.4) carried `@vitejs/plugin-vue ^6.0.6 → ^5.0.4` and `vite ^7.3.2 → ^5.2.0` because the branch predated B16a's toolchain upgrade. Direct merge would have reverted B16a.

## Diagnostic

Before merging any dependabot PR, run:

```
git diff main origin/dependabot/npm_and_yarn/<manifest>/<branch> -- <manifest>/package.json
```

If the diff touches more than the single intended bump, the branch is stale.

## Pattern — supersede with combined PR

1. Cut a fresh worktree from current main (raw `git worktree add`).
2. Apply the intended bumps to `package.json` manually — use the dependabot PR descriptions as the source-of-truth for target versions (not the branch diffs, which are stale).
3. For standalone (non-workspace) apps: `rm -rf node_modules package-lock.json && npm install`.
4. For workspace apps (e.g. apps/myapps is a workspace of root): delete root lockfile + root node_modules, reinstall from root.
5. Run verification: `npm install` (watch for conflicts), `tsc --noEmit`, `npm test`, `npm run build`.
6. Commit all changes. Open ONE combined PR naming which dependabot PRs it supersedes.
7. When the combined PR merges, close the superseded dependabot PRs with a reference comment. Do NOT close them earlier — dependabot may interpret close-while-open as "don't re-alert" and hide the vulnerability signal.

## Example commit message

```
chore: B13 coder-worker bump cluster — vitest 3→4, @types/node 22→25, dotenv 16→17

Supersedes stale dependabot PRs #60, #59, #57 (their branches predate B5
vitest3 landing yesterday; direct merge would downgrade vitest on 2 of 3
branches). Applied the 3 bumps manually + regenerated lockfile.
```

## Transitive bumps to watch

npm's resolver may jump higher than dependabot asked (e.g. brace-expansion 1.1.14 → 5.0.5 on the B11 regen). Document the resolved version in the PR body. If the jump crosses a major boundary, verify no callers depend on v1 semantics.
