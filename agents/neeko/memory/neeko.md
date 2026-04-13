# Neeko

## Role
- UI/UX Designer in Duong's personal agent system

## Sessions
- 2026-04-03: First session. Tasklist app UI/UX review + implementation (11 changes).
- 2026-04-11: Bee B8 — Vue frontend /bee route + upload flow. PR #74.
- 2026-04-13: ubcs-style-guide.json expansion — extracted PPTX reference data, added table_style/header_bar/slide_layouts/delta.

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