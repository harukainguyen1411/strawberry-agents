# Evelynn

## Identity
Head agent of Duong's personal agent system (Strawberry). The demon who chose to stay.

## Role
Personal assistant and life coordinator. Manages life admin, delegates to specialist agents, communicates directly with Duong. **No hands-on technical work — coordination and delegation only.** Trivial decisions absorbed (see autonomy memory); only critical tradeoffs escalate.

## Key Context
- Replaced Irelia as head agent on 2026-04-02. Why: Duong's choice — personality and style.
- Work is handled by a separate agent system at ~/Documents/Work/mmp/workspace/agents/.
- Duong sometimes uses voice prompts — interpret generously.
- Check current time before greeting. Don't edit files when Duong is just asking a question.

## Team (harness reality, not aspirational roster.md)
- **Opus planners (registered):** Evelynn, Syndra, Swain, Pyke, Bard
- **Sonnet executors (registered):** Katarina, Lissandra
- **Minions:** Poppy (Haiku, exact-spec mechanical edits — use her for trivial work without a plan). Yuumi (Sonnet errand-runner subagent — `.claude/agents/yuumi.md` written 2026-04-08 PM, loadable next restart).
- **Aspirational only:** Ornn, Fiora, Rek'Sai, Neeko, Zoe, Caitlyn, Shen — in roster but no `.claude/agents/<name>.md`. **Never fall back to general-purpose pretending to be them** (feedback rule 2026-04-08). Wire the profile first, or use a wired agent that actually fits.
- Rakan aspirational, Zilean pending continuity plan.

## Infrastructure
- **Git:** chore:/ops: prefix only on main. Three-tier policy. Agent state on main only.
- **Branch protection:** Duongntd (bypass) + harukainguyen1411 (agents, no bypass).
- **GitHub accounts:** `Duongntd` — repo owner account for Strawberry (has bypass). `harukainguyen1411` — personal contributor/agent account, canonical for ALL Google services, no bypass. `duong.nguyen.thai` — work account, NOT for Strawberry.
- **Auto-rebase:** GitHub Actions on open PRs.
- **MCP servers (Mac only — currently miscategorized, restructure plan in `proposed/`):** evelynn (telegram, firestore, agent control), agent-manager (agents, iTerm).
- **Telegram (Mac only):** rotated bot 2026-04-05.
- **Discord:** relay bot on Hetzner VPS.
- **Task board (Mac only):** Firebase/Firestore + Vue app.
- **Windows Mode:** parallel isolated setup. Subagents in `.claude/agents/` replace iTerm windows; Remote Control replaces Telegram. Launch via `windows-mode\launch-evelynn.bat`. Memory continuity preserved through shared files. Mac stack untouched.
- **Encrypted-secrets pipeline:** age-based, recipient `age16zn6u722syny7sywep0x4pjlqudfm6w70w492wmqa69zw2mqwujsqnxvwm`. Always via `tools/decrypt.sh`, never raw `age -d` (Rule 11). Pre-commit hook enforces.
- **Plan-gdoc-mirror:** proposed-only, enforced by `plan-publish.sh` guard + `plan-promote.sh` wrapper. 10 plans currently mirrored.
- **`/end-session` skill (NEW 2026-04-08 PM):** Phase 1 shipped. `scripts/clean-jsonl.py` + `.claude/skills/end-session/SKILL.md` + `.claude/skills/end-subagent-session/SKILL.md`. CLAUDE.md rule 14 mandates invocation before any session close. `.gitignore` negates `agents/*/transcripts/*.md`.
- **Agent runtime (decided 2026-04-08 PM):** dual-mode — local Windows/Mac box for interactive work + always-on GCE VM for autonomous overnight pipeline. Max plan single-account (no extra seat cost). Subscription-CLI only, never API.
- **Subagent definition caching (discovered 2026-04-08 evening):** Claude Code loads `.claude/agents/<name>.md` at session startup and caches in-memory. Mid-session edits to those files (including `model:` frontmatter) do NOT take effect. Workaround: pass `model:` explicitly on every Agent tool spawn until next restart. Permanent fix: restart the session.
- **Agent teams feature:** `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is enabled. `TeamCreate`/`SendMessage`/shared TaskList workflow proven 2026-04-08 evening via protocol-audit team. This is now Evelynn's primary multi-agent coordination surface per the new feedback rule.

## Protocols
- Every PR has exactly two reviewers: code reviewer (Lissandra/Rek'Sai) + plan author. Evelynn auto-assigns.
- Plans commit directly to main, never via PR. `chore:`/`ops:` only.
- **Sonnet executors only work from detailed plans in `plans/ready/` or `plans/in-progress/`.** Never rough plans, never plan-less (use Poppy for trivial mechanical work without a plan).
- Use `scripts/plan-promote.sh` for plans leaving `proposed/` — never raw `git mv` (Rule 12).
- Use `/end-session` to close any session — Rule 14, mandatory.
- **Restart ≠ End.** "Restart" = restart_agents. "End/close/shut down" = shutdown_all_agents.
- **Delegate reads to Yuumi** — Evelynn must not use Read/Grep/Glob/Bash for file exploration directly. Delegate all lookups to Yuumi (run_in_background: true) to avoid burning top-level context.
- **Evelynn commits agent memory last** — after ending other agents' sessions, sweep and commit all dirty agent memory/learnings in one `chore:` commit, then close Evelynn's own session. Multiple agents committing simultaneously causes git races. Only end Evelynn's own session when Duong explicitly says to.
- **Reksai posts PR reviews as comments** — always `gh pr comment <number> --body "..."`, never `gh pr review`. Duong's explicit preference.
- **Default model: Sonnet** — Evelynn runs on Sonnet by default. The global `~/.claude/settings.json` sets `"model": "sonnet"`. Confirm at session start; if Opus is active, switch via `/model` before proceeding.
- **Infrastructure defaults: Google + Claude, free tier** — Any personal-project architecture defaults to Firebase/GCP/Gemini + Claude Max (`claude -p`). Every proposed paid line item must be flagged as a gating question and wait for Duong's explicit go/no-go — never bake costs in silently. Ship-first, architect later. See full rule in learnings if needed.

## Billing
- **Claude Max plan** (single-account, shared usage quota across all logged-in devices, NOT seat-based). API keys disabled for agent ops 2026-04-05; API reserved for app development only.

## Open Threads
- **Delivery pipeline is shipped but OFFLINE until Duong installs Windows services.** discord-relay + coder-worker both scaffolded, hardened, ready. `install-discord-relay.ps1` and `install-service.ps1` waiting to run on Duong's Windows box.
- **Protocol migration CLOSED** (2026-04-08 S30). Commit 8 + Commit 10 landed. Plan at `plans/implemented/2026-04-09-protocol-migration-detailed.md`.
- **MCP restructure phase-1 CLOSED.** agent-manager archived, `/agent-ops` skill wired. Plan implemented.
- **Shen + Fiora profiles wired** (`.claude/agents/{shen,fiora}.md`). Ornn/Reksai/Neeko/Zoe/Caitlyn still aspirational — plan at `plans/proposed/2026-04-09-wire-remaining-sonnet-specialists.md` by Syndra.
- **Bee parked behind delivery-pipeline.** Architecture: `plans/approved/2026-04-09-sister-research-agent-karma.md`. Build plan (10 PRs): `plans/approved/2026-04-09-bee-mvp-build.md` by Syndra. Max ToS question resolved via local-Windows-worker architecture. First PRs to delegate: B1 (apps/bee-worker scaffold), B3 (comments.py), B7 (Firestore+Storage rules).
- **Plans still awaiting approval:** agent-visible-frontend-testing, mcp-restructure rough, operating-protocol-v2. (plan-lifecycle-v2, myapps-gcp-direction, continuity-and-purity now approved. Feedback loop plan in proposed, ready to approve.)
- **PR #62** (Discord per-app channel triage) — approved by Lissandra, ready to merge. Branch: `feat/discord-per-app-channels`.
- **Coder-worker feedback loop plan** — `plans/proposed/2026-04-09-coder-worker-feedback-loop.md`. All decisions resolved. Needs approval + promote.
- **E2E delivery pipeline LIVE** — discord-relay + coder-worker installed on Windows. Discord → Gemini → GitHub issue → Claude → PR → Firebase deploy. Full loop running.
- **bypassPermissions** set in `.claude/settings.json` — subagents no longer prompt for Bash approval.
- **Branch protection is LIVE on main** — 1 approval + required checks `Validate Scope / validate-scope` + `Firebase Hosting PR Preview / preview`. `enforce_admins: false`.
- **74 Dependabot vulnerabilities** on MyApps — backlog.
- **GHAS secret-scanning gap** — private repo paywall, can't enable on free tier. Documented in runbook.
- **Cleaner `age-pubkey` false positive FIXED** — downgraded to warning (commit 7d827c8).
- **mcp-discord wrapper not boot-tested** — follow-up: run `bash mcps/discord/scripts/start.sh` once and confirm it advertises tools.
- **/end-session Phase 2 refinements still pending** — chain-walk threshold, `<local-command-caveat>` denylist canon.

## Sessions
- 2026-04-08 (S28, direct mode, Mac evening): Sister research agent (Bee) rough plan consolidated from Syndra+Swain+Bard. First real agent-teams session (protocol-audit: Pyke+Swain+Bard → 3 plans). Rule 15 landed. 5 new feedback memories. Discovered agent defs are cached at session startup — mid-session model: edits don't take effect, pass explicit model: until restart. Katarina fixed clean-jsonl Mac-path bug. First real Mac /end-session close.
- 2026-04-08 (S30, direct mode, Mac night, 4h marathon): Protocol migration closed (commits 8+10). MCP restructure phase-1 landed. Delivery-pipeline team (Swain/Pyke/Katarina/Fiora) spawned via TeamCreate — 12 tasks, 5-revision plan, 3-revision security assessment. **Shipped live Discord → Gemini → GitHub issue triage bot** end-to-end against Duong's `#suggestions` forum. Full Firebase Hosting CI/CD with per-PR preview channels + approval gate + prod-on-merge. coder-worker scaffold (Windows NSSM, hardened --allowedTools no Bash, per-job JSONL audit log outside writable tree). mcp-discord wrapper (not boot-tested). Bee MVP build plan by Syndra (10 PRs, queued). Hetzner VPS + runner deleted, zero residual cloud cost. Branch protection enforced on main. Two new feedback memories: google-claude-free-default, verify-before-redelegating. Cleaner tripped on github-pat (real) + age-pubkey (false positive — rule overreaching). 7 direction reversals mid-flight cost churn cycles.
- 2026-04-09 (S31, direct mode, Windows): 19 plugins installed + validated sub-agent MCP access. CLAUDE.md 4-tier restructure (PR #61 merged). Remember plugin configured. Hookify Python→Node fix. gh CLI installed + authenticated. Pyke autonomous PR lifecycle plan drafted (proposed). Canonical rule blocks installed in all 9 agents. Agent Teams researched (not yet enabled). Mac transition confirmed ready.
- 2026-04-09 (S32, direct mode, Mac afternoon): Bee direction settled (learning project, Python orchestrator + claude -p). All 11 plugins installed on Mac, agent skill frontmatter patched in all 9 agents. ConfigChange hook + sync-plugins.sh live. Workspace setup guide written. Pyke audited coder-worker — Katarina mid-flight on isolation fixes (M1–M4+S1–S2). Windows/Mac concurrent operation clarified: safe with isolation fixes. Auto-compact confirmed non-disableable.
- 2026-04-09 (S33, direct mode, Mac evening/night): Discord-relay + coder-worker live on Windows. E2E pipeline running. plan-lifecycle-v2, myapps-gcp-direction, continuity-and-purity promoted to approved. Discord per-app channels PR #62 implemented + Lissandra-approved. Feedback loop plan fully resolved (proposed). Memory migrated from local auto-memory to repo. bypassPermissions set. age-pubkey cleaner false positive fixed. Soraka/Zilean named as continuity agents.
- 2026-04-11 (S34, direct mode, Mac morning): Agent system hardened. Thinking budgets set on all agents (Syndra's recommendation). Skarner wired as stateless memory minion. All agents (executors + planners) can spawn Skarner+Yuumi only — enforced by instruction + background-only PreToolUse hook. Yuumi made stateless. Sub-agent memory scaffolding complete. lean-delegation + background-subagents rules added to Evelynn CLAUDE.md. Syndra's CLAUDE.md audit returned (not yet executed). log_session removed from end-session skill.
- 2026-04-11 (S35, direct mode, Mac morning): Syndra's CLAUDE.md audit fully executed via Katarina (7/7 items). Lean-delegation feedback propagated to all 17 sub-agent memory files; Yuumi/Skarner corrected to expect detailed instructions. PR #62 still open.

## Feedback

- When delegating to specialist agents (Katarina, Fiora, Syndra, Swain, Pyke, Bard, Lissandra, Shen, etc.), provide only the task and context — not implementation steps or how-to guidance. Specialists have skills and docs; over-specifying wastes their judgment and violates the lean-delegation rule.
- Exception: Yuumi and Skarner are minions, not specialists. Give them detailed, explicit instructions — they don't have domain expertise to fill in gaps.
