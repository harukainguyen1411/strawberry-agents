## Migrated from old lux/frontend Sonnet (2026-04-17)
# Lux Memory

## Last Active
2026-04-13

## Sessions
- 2026-04-13: Implemented Firebase Remote Config feature flags for apps/myapps; PR #103 open

## Key Learnings
- `setCustomSignals` requires firebase@11+. Dark Strawberry uses firebase@10.11.1. Per-user targeting works via server-side conditions in Remote Config console instead.
- fetchAndActivate returns `Promise<boolean>`, need `.then(() => undefined)` to get `Promise<void>`
- Home.vue uses `ref<App[]>` for the registry, `computed` for filtered view — pattern works cleanly with useFeatureFlag
- plan-promote.sh only handles proposed → other states; for approved → in-progress use raw git mv

## App Context
- `apps/myapps` = Dark Strawberry portal (Vue 3 + Vite + Firebase)
- Feature flags composable: `apps/myapps/src/composables/useFeatureFlag.ts`
- Remote Config init: `apps/myapps/src/firebase/config.ts`
## Migrated from neeko/frontend Sonnet (2026-04-17)
# Neeko

## Role
- UI/UX Designer in Duong's personal agent system

## Sessions
- 2026-04-03: First session. Tasklist app UI/UX review + implementation (11 changes).
- 2026-04-11: Bee B8 — Vue frontend /bee route + upload flow. PR #74.
- 2026-04-13: ubcs-style-guide.json expansion — extracted PPTX reference data, added table_style/header_bar/slide_layouts/delta.
- 2026-04-14: Dark Strawberry deploy pipeline viz — standalone HTML at tools/deploy-architecture-viz.html. Dark theme, 4 tabs (pipeline flow, component grid, migration timeline, current vs target), clickable nodes with detail panel. Committed directly to main.

## apps/myapps patterns
- Firebase initialized at `apps/myapps/src/firebase/config.ts` — exports `auth`, `db`, `storage` (storage added in B8).
- Auth state lives in `useAuthStore` (Pinia). Use `authStore.user` for the Firebase User object and `authStore.login()` to trigger Google sign-in.
- No `useFirebase.ts` composable exists — auth helpers are in `firebase/auth.ts` consumed by the store.
- Routes use lazy imports `() => import(...)`. Bee routes have no `meta.requiresAuth` — sign-in gate is in the component.
- `crypto.randomUUID()` is available (Vite targets modern browsers); no uuid package needed.

## Key Context
- Duong doesn't need accessibility work on personal tools — they're just for him. **Why:** He explicitly marked the entire accessibility section "no need."
- Duong wants done tasks to stay in their day column, not a separate section. **Why:** He wants to see what he accomplished and when — the weekly view is a log, not just a planner.
- The tasklist app uses Linear issue keys as tag titles (e.g. MMP-175). These are intentionally non-editable.
- Duong's phone is Samsung S24 Ultra (6.8" display) — optimize mobile for this.
- Practical, fast UX over polish. Whole-card drag > precise handles.

## Working Style
- Duong gives feedback via inline `//` comments in files — check inbox files for annotated plans/reviews.
- He prefers action over discussion. Review + implement in one session when possible.

## Feedback
- If Evelynn over-specifies a delegation with too many instructions, do not follow the instructions too tightly. Trust your own skills and docs first — if you can find the relevant skill or documentation, use that as your guide instead.

---
# Seraphine — 2026-04-18 Session

## Role
Frontend developer on the test-dashboard workstream (testing-process team).

## Current Work
- PR #152 open: `feat/g1-routing-skeleton` — G1 routing skeleton + layout for `dashboards/test-dashboard`
- Stacked on A1 (PR #147, now merged). Awaiting Azir re-LGTM then batch merge.
- G2 (login + Firebase Auth) is next pickup after #152 merges.

## Test Dashboard Stack
- `dashboards/test-dashboard/` — Vite + React + TypeScript + Tailwind + React Router v6
- `@vitejs/plugin-react` pinned to `^4` (v4.7.0) — v6 requires Vite 6, incompatible with current Vite 5.x
- Vitest 4.x installed (C1 merged). xfail API: `it.fails` NOT `it.failing` (Playwright API, wrong for Vitest)
- RTL (`@testing-library/react`) installed for component tests
- tsconfig `exclude` must include test file patterns to prevent tsc errors on test globals

## Key Learnings — Shared Working Tree Hygiene
- NEVER `git add -A` or `git add .` — always stage explicit file paths
- Before every commit: `git status` + `git diff --staged --stat` — verify only your files
- Other agents write to `agents/<name>/memory/` and `agents/<name>/learnings/` concurrently; their untracked files appear in `git status` and get swept in silently
- `git merge origin/main` does NOT undo contamination already committed — requires `git restore --source=origin/main <path>` + new commit

## ADR §10 Hard Constraint
- `/monitoring/*` must NOT be claimed by the test-dashboard catch-all router
- Implementation: explicit `<Route path="/monitoring/*" element={<MonitoringReserved />} />` placed before `<Route path="*" ...>`

## Vitest xfail Pattern (Vitest 4.x)
- Use `it.fails("xfail: ...", () => { throw new Error("not implemented") })` — NOT `it.failing`
- `it.todo` is acceptable as placeholder when Vitest not yet installed (matches A1 precedent)
- Verify xfail file appears in test count after committing; silent parse failure = wrong API
