# Katarina

## Role
- Fullstack Engineer — Quick Tasks

## Sessions
- 2026-04-09 (S36, subagent): Windows isolation hardening per Pyke's plan. M1: scoped git add to apps/myapps/. M2: fix: -> chore: prefix in worker.ts. M3: fixed stale systemPromptPath default in config.ts. M4/S1: added .claude/ deny list + hard invariant block to system-prompt.md. S2: created architecture/platform-split.md. Plan promoted to implemented. Commits 1712501 + 0b47498 pushed to main.
- 2026-04-09 (S33, subagent): CLAUDE.md three-tier restructure. Created agents/evelynn/CLAUDE.md, architecture/key-scripts.md, architecture/plugins.md, architecture/pr-rules.md. Rewrote root CLAUDE.md to 68-line Tier 1 shape with anchor comments. Built scripts/lint-subagent-rules.sh (POSIX, detects block drift in .claude/agents/*.md). Updated agent-network.md and platform-parity.md with anchor-name refs. Branch: claude-md-restructure, commit eb454fc pushed. PR creation blocked — gh not installed, github-triage-pat.txt stale, .age file invalid. Step 4 (.claude/agents/*.md) and Step 5 (.claude/skills/*.md) blocked by harness write restriction on .claude/ in subagent mode. Evelynn must complete those in a top-level session.
- 2026-04-09 (S35, subagent): Final fix pass on claude-md-restructure. Commit 79da9ba: shell-approval-prompts rule added to SONNET_REF, Rule 1 rationale parenthetical added to root CLAUDE.md, ## For Evelynn Sessions heading added, evelynn-exclusion comment added to lint script, self-referential item 7 removed from evelynn/CLAUDE.md startup sequence. Pushed.
- 2026-04-09 (S34, subagent): Fixed PR #61 blockers on claude-md-restructure branch. Commit 2aa8502: dead anchor in SONNET_REF replaced with plain text, duplicate #rule-plans-direct-to-main renamed to #rule-plans-no-pr in evelynn/CLAUDE.md, empty-glob guard added to lint script, self-ref startup item clarified. Pushed.
- 2026-04-09 (S32, subagent): delivery-pipeline full sweep complete. Cloud Run torn down, Secret Manager + Artifact Registry deleted. discord-relay Windows scripts (install-discord-relay.ps1, start-windows.sh) + icacls lockdown committed. coder-worker scaffold complete: 8 src modules, --allowedTools hardening. Lesson: when Evelynn asks for a patch already shipped, verify with git show and push back firmly.
- 2026-04-09 (S31, subagent): pivot ack — coder agent → Max plan local Windows worker. Generated firebase-hosting-deployer SA for myapps-b31ea; pushed key to Duongntd/myapps as FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA.
- 2026-04-09 (S30, subagent): delivery-pipeline team tasks. GCP APIs enabled. Secrets pushed to Secret Manager. discord-relay deployed to Cloud Run. MyApps deployed to Firebase Hosting (https://myapps-b31ea.web.app). Smoke test PR #55 merged.
- 2026-04-03 (S1): Verified HTML tasklist UI, ported 4 features to Vue migration (myapps PR #53), fixed touch drag regression.
- 2026-04-03 (S2): Built contributor pipeline Discord bot (`apps/contributor-bot/`), applied Swain's review fixes.
- 2026-04-03 (S3): Set up GitHub webhook for Discord #pr-and-issues notifications.
- 2026-04-04 (S4): Built `apps/discord-relay/` bot + `scripts/discord-bridge.sh` + `scripts/result-watcher.sh` for Discord-CLI integration.
- 2026-04-05 (S5): Diagnosed + fixed GH_TOKEN shell scoping bug and per-agent API key isolation in `mcps/agent-manager/server.py`. PRs #29 and #30.
- 2026-04-08 (S15, subagent): Executed Swain's gdoc-mirror-revision plan. Committed in-flight state, migrated 30 plans (unpublish/republish), wrote plan-promote.sh, added CLAUDE rule 12 + agent-network step 10.
- 2026-04-08 (S17, subagent): myapps PR #54 unblock. Fixed firebase.json missing firestore.indexes.json registration (1af0ad3). Strawberry housekeeping — memory + plan promoted.

## Known Repos
- strawberry: Personal agent system (this repo)
- myapps (github.com/Duongntd/myapps): Vue 3 + Vite + Firebase + Tailwind. Strict pre-commit hooks (typecheck + tests + lint).

## Working Notes
- myapps pre-commit runs vue-tsc --noEmit — unused vars will block commits
- All commits use `chore:` or `ops:` prefix (enforced by pre-push hook on main)
- contributor-bot uses ESM (type: module), discord.js 14, @google/generative-ai, @octokit/rest
- discord-relay: ESM, discord.js 14, express only. File-based IPC via JSON in /home/runner/data/
- Per-agent ANTHROPIC_API_KEY is gone — agents now auth via team plan login
- .claude/ directory writes are BLOCKED by harness in subagent mode — cannot update .claude/agents/*.md or .claude/skills/*.md from a subagent invocation
- github-triage-pat.txt is stale; github-triage-pat.age is invalid (EOF error). GitHub API calls fail. Need fresh token before PR automation works.
- scripts/lint-subagent-rules.sh: SONNET_REF and OPUS_REF blocks are the canonical reference. Update these when rules change.
