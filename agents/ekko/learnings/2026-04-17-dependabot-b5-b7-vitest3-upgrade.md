# Dependabot B5-B7 — vitest 2→3 upgrade pattern

## vitest 2→3 is the correct fix for esbuild/vite alert chain in standalone apps

The Dependabot alerts for esbuild <=0.24.2 and vite <=6.4.1 in discord-relay, deploy-webhook, and coder-worker are entirely transitive through vitest 2.x (which pins vite 5.x). `npm audit fix` cannot fix them without `--force` (major crossing). The correct fix is bumping vitest to ^3.x in devDependencies, which pulls vite 7.x and esbuild 0.27.x — both patched.

**Why:** vitest 3 depends on vite 6+; vite 6/7 depends on esbuild >=0.25.0. The entire chain resolves cleanly.

## Non-workspace apps can regen lockfiles directly

Apps not listed in root `workspaces` (discord-relay, deploy-webhook, coder-worker) can have their lockfiles regenerated standalone: delete lockfile → `npm install --package-lock-only` from app dir. No workspace-remove/restore dance needed (that's only for workspace members per Viktor's B2/B3 learnings).

## vitest 3 basic API is stable — safe for simple test files

Tests using only `describe`, `it`, `expect` from vitest are unaffected by the vitest 2→3 upgrade. Only `vi.mock`, `vi.fn` patterns and config changes are the risky surface (B4g concern). For apps with simple unit tests, the upgrade is mechanical.

## Lockfile shrinks on vitest 2→3 upgrade

vite 7 + vitest 3 has a leaner dependency tree than vite 5 + vitest 2. Expect significant line reduction in package-lock.json (discord-relay: ~320 net lines removed). This is expected and acceptable — document in PR description to reassure Jhin.

## Pre-existing build errors don't block the security fix

discord-relay has a pre-existing `Cannot find module 'proper-lockfile'` TS error on main (missing dep in package.json). This is not introduced by the vitest bump and should be documented in the PR as pre-existing. Do not fix it in the security PR — out of scope.
