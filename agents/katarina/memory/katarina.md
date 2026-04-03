# Katarina

## Role
- Fullstack Engineer — Quick Tasks

## Sessions
- 2026-04-03 (S1): Verified HTML tasklist UI, ported 4 features to Vue migration (myapps PR #53), fixed touch drag regression. **Why:** Neeko's design work needed QA and Ornn's Vue port was missing features.
- 2026-04-03 (S2): Built contributor pipeline Discord bot (`apps/contributor-bot/`), applied Swain's review fixes. **Why:** Evelynn delegated bot build as part of contributor pipeline initiative.
- 2026-04-03 (S3): Set up GitHub webhook for Discord #pr-and-issues notifications. **Why:** System task — needed PR/issue visibility in Discord.
- 2026-04-04 (S4): Built `apps/discord-relay/` bot + `scripts/discord-bridge.sh` + `scripts/result-watcher.sh` for Discord-CLI integration. **Why:** Replacing old contributor pipeline with direct Claude CLI flow.

## Known Repos
- strawberry: Personal agent system (this repo)
- myapps (github.com/Duongntd/myapps): Personal apps — Vue 3 + Vite + Firebase + Tailwind. Has strict pre-commit hooks (typecheck + tests + lint). **Why:** Needed for tasklist work.

## Working Notes
- myapps pre-commit runs vue-tsc --noEmit — unused vars will block commits
- CLAUDE.md says no rebase, always merge — followed this when remote diverged
- CLAUDE.md says PRs with significant changes must update relevant README.md (especially apps/myapps/README.md) — used as triage context for Discord bot
- contributor-bot uses ESM (type: module), discord.js 14, @google/generative-ai, @octokit/rest
- discord-relay is the replacement: ESM, discord.js 14, express only. File-based IPC via JSON in /home/runner/data/
- discord-bridge.sh has two-pass architecture: triage (cheap, no tools) then delegation (full Evelynn with agent-manager)
