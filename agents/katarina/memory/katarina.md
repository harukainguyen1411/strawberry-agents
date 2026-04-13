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

## Sessions (recent)
- 2026-04-11 (subagent, S1): Executed subagent-memory-and-skarner plan. Seeded learnings/ for katarina/fiora/shen/yuumi/poppy. Scaffolded agents/skarner/ with profile + memory. Updated end-subagent-session skill with inline steps. Updated agent-network.md + evelynn/CLAUDE.md. Commit 89c51e1.
- 2026-04-11 (subagent, S2): Verified plan completion — all items done. Confirmed .claude/agents/ writes blocked in subagent mode (handled by Evelynn). Committed outstanding memory update.
- 2026-04-11 (subagent, S3): Syndra CLAUDE.md audit. Fixed roster pointer, removed evelynn duplicate rule, moved Operating Modes to evelynn/CLAUDE.md, fixed learnings/ path, trimmed agent-network session closing explainer, reconciled Neeko/Zoe/Caitlyn as aspirational. Commit 1825803. .claude/agents/poppy.md comment blocked by harness — flagged for Evelynn.
- 2026-04-11 (subagent, B5): Bee MVP task B5. Implemented worker.ts (orchestration loop), docx.ts (execa wrapper around comments.py), index.ts (boot + SIGTERM/SIGINT shutdown). Branch feat/bee-mvp-b5, commit 825e54a, PR #75. tsc clean.
- 2026-04-11 (subagent, S4): windows-push-autodeploy plan. apps/deploy-webhook (HMAC webhook + health + file-lock detached spawn), scripts/windows/deploy-services.json + deploy-all.ps1 + deploy-service.ps1 + install-deploy-webhook.ps1. Branch feat/windows-push-autodeploy, commit ea87964, PR #89. tsc clean.
- 2026-04-11 (subagent, S5): subagent-stop-hook plan blocked — .claude/ writes denied by harness in subagent mode. Needs Evelynn top-level session.
- 2026-04-11 (subagent, S6): PR #89 review fixes. Restored agents/pyke/memory/pyke.md to main state. Added npm ci before npm run build in deploy-service.ps1. Added stale lock detection (10 min) with timestamp in lock file to index.ts. Commit d85507a pushed.
- 2026-04-11 (subagent, S7): PR #89 review loop complete. Fixed DEPLOY_REPO_ROOT guard (exit(1) + no cwd fallback), removed ObjectName from NSSM install, npm ci in install-deploy-webhook.ps1, merged origin/main. Commits 9514791/40ddb8f/2ea1435/e04a478. PR approved by Lissandra.
- 2026-04-11 (subagent, S9): Set 7 VITE_FIREBASE_* secrets on Duongntd/myapps via gh secret set. Patched deploy-release.yml Build step to use individual secrets instead of FIREBASE_CONFIG JSON parse step. Commit 050359d, pushed to main.
- 2026-04-11 (subagent, S10): cloudflare-gcp-mcp-servers plan. Promoted plan to approved. Created mcps/cloudflare/scripts/start.sh + mcps/gcp/scripts/start.sh + READMEs. Commit 836f8a0 pushed to main. .mcp.json edit/write BLOCKED by harness — Evelynn must add cloudflare+gcp entries in a top-level session.
- 2026-04-11 (subagent, S8): Wrote docs/windows-services-runbook.md — services table, manual restart, autodeploy setup (install script, firewall/Cloudflare/ngrok, GitHub webhook), adding new service. Commit fac563d, direct to main.
- 2026-04-12 (subagent): Monitored MyApps prod deploy — succeeded after FIREBASE_SERVICE_ACCOUNT secret was added. apps.darkstrawberry.com confirmed live.
- 2026-04-12 (subagent, darkstrawberry-branding): DS icon rollout on feat/platform-monorepo. Copied DsIcon.vue + icons.ts + index.ts from apps/shared/ui/icons/ into worktree. Updated AppManifest.icon type to DsIconName. Updated all 4 app manifests (book/chart-line/checklist/bee). Replaced emoji in Home.vue, AccessDenied.vue, PlatformHeader.vue with DsIcon. Added Neeko footer credit (neeko icon) to PlatformLayout.vue. Commit 4920dd7 pushed.
- 2026-04-12 (subagent, deployment-architecture): Phase 1 + Phase 5. Phase 1: standalone Vite packages for Read Tracker, Portfolio Tracker, Task List, Bee. Phase 5: portal conversion — stripped all app views/components/stores from apps/myapps, Home.vue uses window.location.href to standalone SPAs, router has no app subtrees. All builds clean. Commits cfca63d–f7eeba5, PR #100.
- 2026-04-13 (subagent, retro-skill-body-strip): Wrote scripts/strip-skill-body-retroactive.py. Stripped 810 KB of skill-body leaks from 18 transcripts across caitlyn/evelynn/katarina/lissandra/ornn/pyke/vex. Merged to main. No remote repo — PR not possible.

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

## Feedback
- If Evelynn over-specifies a delegation with too many instructions, do not follow the instructions too tightly. Trust your own skills and docs first — if you can find the relevant skill or documentation, use that as your guide instead.