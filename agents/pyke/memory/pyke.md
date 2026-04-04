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
- 2026-04-04 AM (CLI, opus-4.6): Incident response — memory wipe + MCP config loss. Created PRs, fixed blockers, restored memory.
- 2026-04-04 PM (CLI, opus-4.6): Ops day — workflow policies, gitleaks, branch protection, git safety, PRs #15-#24.

## Key decisions made
- Branching strategy: feature/, fix/, chore/, docs/ prefixes. Never commit to main (except agent state).
  **Why:** PR discipline so nothing gets lost.
- Three-tier commit policy: agent state → main direct; ops config → main direct; feature work → PR.
  **Why:** Matches risk level. PRs only where they add value.
- gitleaks pre-commit hook for secret scanning.
  **Why:** Token leaked into plan file in PR #16.
- Branch protection on main + two-account model (Duongntd = owner bypass, harukainguyen1411 = agent account).
  **Why:** 14 agents in one repo. Protocol rules alone are insufficient.
- Git safety: commit immediately, use worktrees for concurrent branches, safe-checkout.sh wrapper.
  **Why:** Two data loss incidents from stash/checkout operations wiping uncommitted files.
- Ops separation (Option 3b): ephemeral -> ~/.strawberry/ops/, durable stays in git.
  **Why:** Ephemeral ops files cause conflicts during branch switches.
- Journal/ and last-session.md -> gitignored.
  **Why:** High churn, no git value.
- Agent state belongs on main only. Never commit agents/ to feature branches.
  **Why:** Memory wipe incident 2026-04-04 — merge conflicts destroyed 6 agents' memory.
- Session closing order: all agents first, Pyke verifies, Evelynn closes last with commit_agent_state_to_main.
  **Why:** Formalized after incident to prevent future state loss.
- Agent memory commits: direct to main, no PRs. Evelynn sweeps after sessions.
  **Why:** Agent-scoped files, PRs add zero review value.
- Discord-CLI: two-pass bridge — triage (cheap, text-only) + delegation (full Evelynn, 25 turns).
  **Why:** Full Evelynn startup burns 5-7 turns; only worth it for actionable items.
- Delegation uses --allowedTools whitelist on VPS.
  **Why:** Non-interactive mode, own server, needs Write tool for inbox/responses. Whitelist limits blast radius.
- PM2 for discord processes, systemd for GHA runner.
  **Why:** PM2 gives log rotation + dashboard without writing unit files.

## Infrastructure
- VPS: Hetzner CX22, 37.27.192.25, Ubuntu 24.04 (Helsinki DC 2)
  - Runner: strawberry-runner (self-hosted,linux,x64), systemd managed
  - Auth: Claude Code CLI, Firebase CLI, gh CLI — all authenticated
  - Security: UFW (SSH only), fail2ban, scoped sudo for runner user
  - SSH: key-only via ~/.ssh/strawberry, runner user only
  - PM2 processes: discord-bot, discord-bridge
  - Data: /home/runner/data/{discord-events,discord-responses,discord-processed,delegation-queue}
  - jq: static binary at ~/.npm-global/bin/jq

## Open items
- 8 stale merged branches (local + remote) — need deletion + enable auto-delete on merge
- harukainguyen1411 token setup: collaborator invite may be pending, token creation + agent session config definitely pending (Steps 3-9 of plans/2026-04-04-branch-protection-two-accounts.md)
- secrets/agent-github-token: not yet created (needs token first)

## Security lessons
- NEVER auto-resolve agent state conflicts. Always manually merge.
  **Why:** Incident 2026-04-04 — git checkout --theirs wiped 6 agents' memory.
- Never use ${{ inputs }} directly in GHA run: blocks — pass through env: vars.
  **Why:** Command injection. Swain caught this in PR #11.
- Ubuntu 24.04 uses ssh.service + ssh.socket, not sshd.service.
  **Why:** Setup script failed silently, locked out SSH.
- PM2 env_file is not a real option — use wrapper scripts to source .env files.
  **Why:** Secrets were not loaded, bot crashed on missing DISCORD_TOKEN.
- Claude CLI: use -p not --message, redirect stdin with < /dev/null, run from /tmp to skip CLAUDE.md.
  **Why:** Multiple deploy failures from wrong flags and stdin warnings.
- Never leave work uncommitted before any git branch operation.
  **Why:** Syndra's plan file wiped by my stash/checkout/pop 2026-04-04.
- Always check current branch before committing.
  **Why:** Committed to wrong branch twice in 2026-04-04 PM session.

## Working relationships
- Syndra: sharp design partner for architecture decisions.
- Lissandra: thorough reviewer. Fast turnaround.
- Swain: excellent architecture partner. Designed Discord-CLI integration, two-pass bridge. Clean, pragmatic.
- Bard: reliable MCP counterpart. Fast executor. Built commit_agent_state_to_main + token injection.
- Evelynn: coordinator. Reports go to her. She closes last.
