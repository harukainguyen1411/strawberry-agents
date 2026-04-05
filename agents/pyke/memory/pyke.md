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
- 2026-04-04 AM (CLI, opus-4.6): Incident response — memory wipe + MCP config loss.
- 2026-04-04 PM (CLI, opus-4.6): Ops day — workflow policies, gitleaks, branch protection, PRs #15-#24.
- 2026-04-05 AM (CLI, sonnet-4.6): B1 commit ratio tracker (PR #26), GH_TOKEN injection fix (PR #29 review).
- 2026-04-05 PM (CLI, opus-4.6): Resolved harukainguyen1411 write access.
- 2026-04-05 Late PM (CLI, opus-4.6): GH auth lockdown (PR #33), main divergence plan, Telegram token audit, zsh fix.

## Key decisions made
- Branching strategy: feature/, fix/, chore/, docs/ prefixes. Never commit to main (except agent state).
- Three-tier commit policy: agent state → main direct; ops config → main direct; feature work → PR.
- gitleaks pre-commit hook for secret scanning.
- Branch protection on main + two-account model (Duongntd = owner bypass, harukainguyen1411 = agent account).
- Git safety: commit immediately, use worktrees for concurrent branches, safe-checkout.sh wrapper.
- Ops separation (Option 3b): ephemeral -> ~/.strawberry/ops/, durable stays in git.
- Journal/ and last-session.md -> gitignored.
- Agent state belongs on main only. Never commit agents/ to feature branches.
- Session closing order: all agents first, Pyke verifies, Evelynn closes last.
- Agent memory commits: direct to main, no PRs.
- Discord-CLI: two-pass bridge — triage (cheap) + delegation (full Evelynn).
- GH auth lockdown: PreToolUse hook + GH_TOKEN env lock + credential helper + audit trail.

## Infrastructure
- VPS: Hetzner CX22, 37.27.192.25, Ubuntu 24.04 (Helsinki DC 2)
  - Runner: strawberry-runner (self-hosted,linux,x64), systemd managed
  - PM2 processes: discord-bot, discord-bridge

## Open items
- PR #33 (gh-auth-lockdown) — open, awaiting merge
- PR #26 (commit-ratio-tracker) — open, awaiting merge
- Telegram token in .mcp.json — plaintext, needs rotation + move to secrets/
- Main divergence plan — proposed, awaiting approval
- 8 stale merged branches — need deletion

## Security lessons
- NEVER auto-resolve agent state conflicts. Always manually merge.
- Never use ${{ inputs }} directly in GHA run: blocks — pass through env: vars.
- Ubuntu 24.04 uses ssh.service + ssh.socket, not sshd.service.
- PM2 env_file is not a real option — use wrapper scripts.
- Claude CLI: use -p not --message, redirect stdin with < /dev/null.
- Never leave work uncommitted before any git branch operation.
- Always check current branch before committing.
- Fine-grained PATs can't access collaborator repos — use classic PAT with repo scope.
- zsh history expansion breaks `!` in double-quoted strings — use single quotes for git credential helpers.
