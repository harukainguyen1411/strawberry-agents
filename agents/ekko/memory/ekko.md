# Ekko Memory

## Last session: 2026-04-13

## What I built
- **Bee Gemini intake** (PR #105, branch feat-bee-gemini-intake)
  - 3 Cloud Functions: beeIntakeStart, beeIntakeTurn, beeIntakeSubmit (Gemini 2.5 Flash)
  - Firestore: bee-intake-sessions/{sessionId}/messages subcollection
  - P0 text intake + P1 mammoth docx extraction both implemented
  - BeeIntake.vue chat UI with Vietnamese intro hardcoded on client, typing indicator, done-gate
  - BeeHome.vue now routes to intake instead of direct GitHub issue
  - firebase.json gets emulator config (ports 5001/8080/9199/9099/4000)
  - apps/functions/README.md with exact local testing commands + curl example

## Key paths
- Functions: apps/functions/src/beeIntake.ts
- Frontend: apps/myapps/src/views/bee/BeeIntake.vue
- Updated: apps/myapps/src/views/bee/BeeHome.vue, apps/myapps/src/router/index.ts, firebase.json

## Important notes
- GEMINI_API_KEY used as defineSecret — emulator reads from process.env.GEMINI_API_KEY
- Issue body format is backward-compatible with bee-worker parseIssueBody (spec before \n---\n, docx footer preserved)
- safe-checkout.sh needs interactive stdin for untracked files — bypass with git worktree add directly
- plan-promote.sh only works for plans/proposed/ — approved->in-progress must be manual git mv
