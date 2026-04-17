# B8 — vite 5→7 direct dep bump learnings

## @vitejs/plugin-vue peer dep range covers vite 7

`@vitejs/plugin-vue@6.x` declares `peerDependencies: { vite: "^5.0.0 || ^6.0.0 || ^7.0.0 || ^8.0.0" }`. Safe to bump plugin-vue from ^5 to ^6 alongside vite 7 — no config changes required.

## vite 7 dedupes in root lockfile when bumping leaf package.json

When bumping direct vite deps in leaf apps that are workspace members, npm resolves vite 7 at the root `node_modules/vite` level. No nested `vitest/node_modules/vite` entry is created — vitest dedupes against the hoisted copy. This matters for surgical patch coordination (B4h targeted a nested entry that B8 didn't touch).

## Root lockfile conflicts are expected when multiple batches land concurrently

B4d and B4f both modified root `package-lock.json` via workspace hoisting before B8 merged. Resolution pattern: `git checkout origin/main -- package-lock.json`, then `npm install --package-lock-only` to regenerate from current package.json state. This produces the correct merged lockfile without manual conflict editing.

**Why:** npm lockfile conflicts in workspace monorepos are structural — the lockfile encodes the full resolved graph. Regenerating from package.json is always safer than manual conflict resolution.

## Pre-existing test mock gap: firebase/config mock missing remoteConfig

`apps/myapps/src/test/setup.ts` mocked `@/firebase/config` but omitted `remoteConfig`, and had no mock for `@/composables/useFeatureFlag`. This broke `Home.spec.ts` silently after `useFeatureFlag` was added to `Home.vue`. Fixed by adding `remoteConfig: {}` to the config mock and a `vi.mock` stub for the composable. Pattern: when a composable directly calls Firebase SDK functions (not just reads exports), mock the composable — not just the config module.

## Alert number scope: direct vs transitive

Dependabot alert numbers reference specific manifest paths. Direct dep alerts (leaf `package.json`) and transitive lockfile alerts (`package-lock.json` entries) are separate alert numbers even for the same package. B8 closed #82–85 (direct); the transitive myapps lockfile vite alerts (#63–66) required a separate surgical patch (B4h by Viktor).
