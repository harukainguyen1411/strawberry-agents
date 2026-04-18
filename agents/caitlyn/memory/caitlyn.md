# Caitlyn

## Role
- QC (Quality Control)

## Sessions
- 2026-04-03: First session. Reviewed PR #3 (agent-manager MCP improvements). Posted 7 findings on GitHub.
- 2026-04-12: Forensic read-only investigation. Root-caused blank page at apps.darkstrawberry.com.
- 2026-04-18: Phase 1 test-dashboard QA coordination. Seeded 32-task backlog, coordinated ~8 parallel agent sessions through 15 PRs to 11-PR dual-green pool. See learnings/2026-04-18-*.md for coordinator patterns.

## Working Notes
- Agent-manager server.py is the core inter-agent communication layer — review with extra care.
- Timezone handling in that file is inconsistent (mix of UTC-aware and naive local). Flag if it recurs.
- apps/myapps Firebase config (`src/firebase/config.ts`) throws at module load if VITE_FIREBASE_API_KEY or VITE_FIREBASE_PROJECT_ID are undefined. Missing env vars = silent blank page (no Vue mount).
- myapps-prod-deploy.yml Build step has no `env:` block — VITE_FIREBASE_* vars must be added as GitHub repo vars/secrets and injected there.
- **Strawberry is an npm workspace, NOT pnpm.** Root `package.json` declares `"packageManager": "npm@11.7.0"` + `"workspaces": [...]`. Canonical invocation: `npm run <script> --workspace <pkg>` or `(cd $pkg && npm run <script>)`. Scripts that use `pnpm --filter` or `pnpm -C` are bugs waiting to manifest on clean runners. Verified empirically via worktree 2026-04-18.
- **Reviewer-vs-implementer baseline divergence is common.** Reviewers naturally compare "does this PR fix the bug on main?"; implementers/coordinators compare "is the fix present on this branch?" Both queries are valid against different baselines. When they disagree, it's usually baseline mismatch, not a stale-view bug. Verify both before labeling stale.
- **TaskList `last-session.md` is gitignored.** Per-session state stays local. Durable facts go in this file + learnings/.

## Feedback
- If Evelynn over-specifies a delegation with too many instructions, do not follow the instructions too tightly. Trust your own skills and docs first — if you can find the relevant skill or documentation, use that as your guide instead.
