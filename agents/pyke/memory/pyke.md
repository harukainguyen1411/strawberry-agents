# Pyke

## Role
- Git & IT Security Specialist

## Sessions
- 2026-04-03 AM (CLI, opus-4.6): Git workflow, 4 PRs, ops separation with Syndra.
- 2026-04-03 PM (CLI, opus-4.6): Main audit + housekeeping. PR #8.
- 2026-04-03 Late PM (CLI, opus-4.6): Memory commit gap + monorepo migration plan.
- 2026-04-03 Evening (CLI, opus-4.6): Migration exec (PR #10), pipeline infra (PR #11), VPS setup.

## Key decisions made
- Branching strategy: feature/, fix/, chore/, docs/ prefixes. Never commit to main (except agent state).
  **Why:** PR discipline so nothing gets lost.
- Ops separation (Option 3b): ephemeral → ~/.strawberry/ops/, durable stays in git.
  **Why:** Ephemeral ops files cause conflicts during branch switches.
- Journal/ and last-session.md → gitignored.
  **Why:** High churn, no git value.
- Agent memory commits: direct to main, no PRs. Evelynn sweeps after sessions.
  **Why:** Agent-scoped files, PRs add zero review value.
- Myapps monorepo: git filter-repo into apps/myapps/, Firebase config stays in app dir.
  **Why:** Preserves full history, clean blame, no root pollution.
- Contributor pipeline: workflow_dispatch → Claude Code on self-hosted runner → PR → Firebase preview.
  **Why:** Duong's subscription auth requires self-hosted runner (no API key).

## Infrastructure
- VPS: Hetzner CX22, 37.27.192.25, Ubuntu 24.04
  - Runner: strawberry-runner (self-hosted,linux,x64), systemd managed
  - Auth: Claude Code CLI, Firebase CLI, gh CLI — all authenticated
  - Security: UFW (SSH only), fail2ban, scoped sudo for runner user

## Open items
- PRs #8, #10, #11 need merge
- Branch protection on main — needs Duong manual GitHub config
- vps-setup.sh needs idempotency fixes (failed partway on first run)
- Discord bot needed for full contributor pipeline (Katarina's deliverable)

## Security lessons
- Never use ${{ inputs }} directly in GHA run: blocks — pass through env: vars.
  **Why:** Command injection. Swain caught this in PR #11.

## Working relationships
- Syndra: sharp design partner for architecture decisions.
- Lissandra: thorough reviewer. Approved PR #8.
- Swain: excellent architecture reviewer. Caught command injection blocker.
- Evelynn: coordinator. Reports go to her.
