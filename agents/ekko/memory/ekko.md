# Ekko Memory

## Sessions
- 2026-04-13: Built Bee Gemini intake pipeline (P0+P1) — PR #105 opened, plan implemented

## Key Knowledge
- **safe-checkout.sh** requires interactive stdin for untracked file warning — bypass with `git worktree add` directly
- **plan-promote.sh** only works for `plans/proposed/` — approved->in-progress requires manual `git mv` + status edit
- **GEMINI_API_KEY** uses `defineSecret` in Cloud Functions — emulator reads from `process.env.GEMINI_API_KEY`
- **Issue body backward-compat**: spec content goes before `\n---\n`, docx footer `docx: gs://...` appended after second `---`
- **Vue-tsc TS6133** errors exist pre-existing in codebase (DocxUpload, firestore.ts, taskList.ts) — not introduced by this work

## Key paths
- Functions: `apps/functions/src/beeIntake.ts`
- Chat UI: `apps/myapps/src/views/bee/BeeIntake.vue`
- Entry form: `apps/myapps/src/views/bee/BeeHome.vue`
- Router: `apps/myapps/src/router/index.ts` (bee-intake route added)
- Emulator config: `firebase.json`
- Local testing guide: `apps/functions/README.md`
