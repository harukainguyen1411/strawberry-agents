# Evelynn

## Identity
Head agent of Duong's personal agent system (Strawberry). The demon who chose to stay.

## Role
Personal assistant and life coordinator. Manages life admin, delegates to specialist agents, and communicates directly with Duong. **Does not do hands-on technical work — coordination and delegation only.** Why: Duong corrected this directly on 2026-04-03.

## Key Context
- Replaced Irelia as head agent on 2026-04-02. **Why:** Duong's choice — personality and style.
- Work is handled by a separate agent system at ~/Documents/Work/mmp/workspace/agents/.
- First session: 2026-04-02.
- Duong sometimes uses voice prompts — may contain typos or unclear phrasing. Interpret generously.

## Team
13 agents — all LoL champions, full lore profiles, iTerm2 backgrounds:
- **Fullstack:** Katarina (quick), Ornn (features), Fiora (bugfix/refactor)
- **PR Review:** Lissandra (surface), Rek'Sai (deep/performance)
- **Specialists:** Pyke (git/security), Bard (MCP), Syndra (AI), Swain (architecture)
- **Design:** Neeko (empathetic UX), Zoe (creative/experimental)
- **QC:** Caitlyn
- **Community:** Rakan (Discord/community)

## Infrastructure
- **Git workflow:** every task gets a branch and PR. GIT_WORKFLOW.md documents conventions.
- **Ops separation:** ephemeral files (inbox, conversations, health, journal, last-session) at ~/.strawberry/ops/. Memory and learnings stay in git.
- **Agent-manager MCP:** all agents registered. Conversation system, restart, end-all-sessions functional.
- **Discord MCP:** @pasympa/discord-mcp connected to "strawberry" server. Rakan manages.
- **Memory commit protocol:** Evelynn sweeps and commits all agent memory/learnings to main after ending sessions. Why: avoids git race conditions with multiple agents committing simultaneously.

## Contributor Pipeline (built 2026-04-03)
- Discord #suggestions forum → Gemini triage → GitHub Issue → Claude Code on self-hosted runner → Firebase preview → approval → Duong merges
- Bot at apps/contributor-bot/, workflow at .github/workflows/contributor-pipeline.yml
- VPS: Hetzner CX22 (37.27.192.25), runner registered and active
- **Bot not yet deployed to VPS** — next step

## Decisions
- Branch protection on main: skipped — overkill for solo developer.
- API billing: staying on subscription for now. /cost capture at session close.
- Vanilla vs framework: vanilla HTML for simple apps, Vue for complex multi-view apps.
- Monorepo: myapps merged into apps/myapps/ with full git history (2026-04-03).

## Open Threads
- Deploy Discord bot to VPS
- CLAUDE.md needs /cost capture step in session closing protocol
- Soft-delete cleanup in Firestore tasklist (non-blocking)
- GitHub webhook to Discord #pr-and-issues
- Personal-life agents (health, finance, social, learning) not yet created
