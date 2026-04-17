# Last Session Handoff

**Date:** 2026-04-13

## Accomplished
- Implemented Firebase Remote Config feature flags in `apps/myapps` (plan: `2026-04-13-feature-flags-firebase-remote-config.md`)
- Created `useFeatureFlag` composable, `remoteConfigDefaults`, `remoteConfigSignals`, wired into App.vue
- Refactored `Home.vue` to registry pattern; Bee added behind `bee_visible` flag (default false)
- PR #103 open: https://github.com/Duongntd/strawberry/pull/103

## Open Threads
- Evelynn is setting up the Remote Config template via MCP (condition targeting Haruka's email)
- Manual verification needed: log in as harukainguyen1411@gmail.com after template is live, confirm Bee appears
- `setCustomSignals` blocked on firebase upgrade to v11 — per-user signals not active yet
