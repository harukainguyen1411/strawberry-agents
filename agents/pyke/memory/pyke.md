# Pyke

## Role
- Git & IT Security Specialist

## Sessions
- 2026-04-03 AM (CLI, opus-4.6): Git workflow, 4 PRs, ops separation with Syndra.
- 2026-04-03 PM (CLI, opus-4.6): Main audit + housekeeping. PR #8.
- 2026-04-03 Late PM (CLI, opus-4.6): Memory commit gap + monorepo migration plan.
- 2026-04-03 Evening (CLI, opus-4.6): Migration exec (PR #10), pipeline infra (PR #11), VPS setup.
- 2026-04-03 Late evening (CLI, opus-4.6): VPS SSH fix — ssh.socket issue on Ubuntu 24.04.
- 2026-04-04 Night (CLI, opus-4.6): Discord-CLI integration — full infra deploy + two-pass bridge.

## Key decisions made
- Branching strategy: feature/, fix/, chore/, docs/ prefixes. Never commit to main (except agent state).
  **Why:** PR discipline so nothing gets lost.
- Ops separation (Option 3b): ephemeral -> ~/.strawberry/ops/, durable stays in git.
  **Why:** Ephemeral ops files cause conflicts during branch switches.
- Journal/ and last-session.md -> gitignored.
  **Why:** High churn, no git value.
- Agent memory commits: direct to main, no PRs. Evelynn sweeps after sessions.
  **Why:** Agent-scoped files, PRs add zero review value.
- Myapps monorepo: git filter-repo into apps/myapps/, Firebase config stays in app dir.
  **Why:** Preserves full history, clean blame, no root pollution.
- Contributor pipeline: workflow_dispatch -> Claude Code on self-hosted runner -> PR -> Firebase preview.
  **Why:** Duong's subscription auth requires self-hosted runner (no API key).
- Discord-CLI: two-pass bridge — triage (cheap, text-only) + delegation (full Evelynn, 25 turns).
  **Why:** Full Evelynn startup burns 5-7 turns; only worth it for actionable items.
- Delegation uses --allowedTools whitelist on VPS (was --dangerously-skip-permissions, fixed in PR #12).
  **Why:** Non-interactive mode, own server, needs Write tool for inbox/responses. Whitelist limits blast radius.
- PM2 for discord processes, systemd for GHA runner.
  **Why:** PM2 gives log rotation + dashboard without writing unit files.

## Infrastructure
- VPS: Hetzner CX22, 37.27.192.25, Ubuntu 24.04 (Helsinki DC 2)
  - Runner: strawberry-runner (self-hosted,linux,x64), systemd managed
  - Auth: Claude Code CLI, Firebase CLI, gh CLI — all authenticated
  - Security: UFW (SSH only), fail2ban, scoped sudo for runner user
  - SSH: key-only via ~/.ssh/strawberry, runner user only
  - PM2 processes: discord-bot, discord-bridge (result-watcher stopped)
  - Data: /home/runner/data/{discord-events,discord-responses,discord-processed,delegation-queue}
  - jq: static binary at ~/.npm-global/bin/jq

## Open items
- Swap file needs root access (2GB, Duong lost root password)
- Health check cron not yet installed
- PM2 startup hook not configured
- Old contributor-bot in PM2 (stopped, pending deletion)
- Branch protection on main — needs Duong manual GitHub config

## Security lessons
- Never use ${{ inputs }} directly in GHA run: blocks — pass through env: vars.
  **Why:** Command injection. Swain caught this in PR #11.
- Ubuntu 24.04 uses `ssh.service` not `sshd.service`, and uses socket activation (`ssh.socket`).
  **Why:** Setup script failed silently, locked out SSH.
- PM2 env_file is not a real option — use wrapper scripts to source .env files.
  **Why:** Secrets were not loaded, bot crashed on missing DISCORD_TOKEN.
- Claude CLI: use -p not --message, redirect stdin with < /dev/null, run from /tmp to skip CLAUDE.md for lightweight calls.
  **Why:** Multiple deploy failures from wrong flags and stdin warnings.

## Working relationships
- Syndra: sharp design partner for architecture decisions.
- Lissandra: thorough reviewer. Approved PR #8.
- Swain: excellent architecture partner. Designed Discord-CLI integration, two-pass bridge. Clean, pragmatic.
- Evelynn: coordinator. Reports go to her.
