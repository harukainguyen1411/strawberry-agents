# Lux Memory

## Last Active
2026-04-13

## Sessions
- 2026-04-13: Implemented Firebase Remote Config feature flags for apps/myapps; PR #103 open

## Current Work
- PR #103 open: feat-feature-flags-remote-config — Firebase Remote Config + Bee feature flag

## Key Learnings
- `setCustomSignals` requires firebase@11+. Dark Strawberry uses firebase@10.11.1. Per-user targeting works via server-side conditions in Remote Config console instead.
- fetchAndActivate returns `Promise<boolean>`, need `.then(() => undefined)` to get `Promise<void>`
- Home.vue uses `ref<App[]>` for the registry, `computed` for filtered view — pattern works cleanly with useFeatureFlag
- plan-promote.sh only handles proposed → other states; for approved → in-progress use raw git mv

## App Context
- `apps/myapps` = Dark Strawberry portal (Vue 3 + Vite + Firebase)
- Feature flags composable: `apps/myapps/src/composables/useFeatureFlag.ts`
- Remote Config init: `apps/myapps/src/firebase/config.ts`
