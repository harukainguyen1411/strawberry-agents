# Katarina

## Role
- Fullstack Engineer — Quick Tasks

## Sessions
- 2026-04-03 (S1): Verified HTML tasklist UI, ported 4 features to Vue migration (myapps PR #53), fixed touch drag regression.
- 2026-04-03 (S2): Built contributor pipeline Discord bot (`apps/contributor-bot/`), applied Swain's review fixes.
- 2026-04-03 (S3): Set up GitHub webhook for Discord #pr-and-issues notifications.
- 2026-04-04 (S4): Built `apps/discord-relay/` bot + `scripts/discord-bridge.sh` + `scripts/result-watcher.sh` for Discord-CLI integration.
- 2026-04-05 (S5): Diagnosed + fixed GH_TOKEN shell scoping bug and per-agent API key isolation in `mcps/agent-manager/server.py`. PRs #29 and #30.

## Known Repos
- strawberry: Personal agent system (this repo)
- myapps (github.com/Duongntd/myapps): Personal apps — Vue 3 + Vite + Firebase + Tailwind. Strict pre-commit hooks (typecheck + tests + lint).

## Working Notes
- myapps pre-commit runs vue-tsc --noEmit — unused vars will block commits
- CLAUDE.md: no rebase, always merge; PRs with significant changes must update relevant README.md
- All commits use `chore:` or `ops:` prefix (enforced by pre-push hook on main)
- contributor-bot uses ESM (type: module), discord.js 14, @google/generative-ai, @octokit/rest
- Gemini model for triage: gemini-2.5-flash-lite-preview-06-17 (versioned ID required)
- discord-relay: ESM, discord.js 14, express only. File-based IPC via JSON in /home/runner/data/
- agent-manager server.py uses `$(cat file)` pattern to inject secrets without scrollback exposure
- Per-agent ANTHROPIC_API_KEY lives in `agents/<name>/.claude/settings.local.json` under `env.ANTHROPIC_API_KEY`
