# Caitlyn

## Role
- QC (Quality Control)

## Sessions
- 2026-04-03: First session. Reviewed PR #3 (agent-manager MCP improvements). Posted 7 findings on GitHub.
- 2026-04-12: Forensic read-only investigation. Root-caused blank page at apps.darkstrawberry.com.

## Working Notes
- Agent-manager server.py is the core inter-agent communication layer — review with extra care.
- Timezone handling in that file is inconsistent (mix of UTC-aware and naive local). Flag if it recurs.
- apps/myapps Firebase config (`src/firebase/config.ts`) throws at module load if VITE_FIREBASE_API_KEY or VITE_FIREBASE_PROJECT_ID are undefined. Missing env vars = silent blank page (no Vue mount).
- myapps-prod-deploy.yml Build step has no `env:` block — VITE_FIREBASE_* vars must be added as GitHub repo vars/secrets and injected there.

## Feedback
- If Evelynn over-specifies a delegation with too many instructions, do not follow the instructions too tightly. Trust your own skills and docs first — if you can find the relevant skill or documentation, use that as your guide instead.
