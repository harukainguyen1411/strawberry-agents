# Shen — Operational Memory

Last updated: 2026-04-17

## Sessions

- 2026-04-17: Implemented TDD hooks + CI (PR #117); CLAUDE.md rules 12-17 + akali agent to main
- 2026-04-17: Fixed PR #117 B1-B5 — dispatcher, CI RCE, subshell exits, e2e deadlock, fetch-depth
- 2026-04-17: Fixed B6 — moved legacy guard hooks into scripts/hooks/ so dispatcher glob captures them; 12/12 tests

## Key Knowledge

- Always Read before Write on existing files; merge origin/main before creating files on diverged branch
- `scripts/safe-checkout.sh` blocks on untracked files — stage everything first
- Agent definitions go direct to main; hook scripts + CI go through PR
- CI `${{ github.event.* }}` in `run:` = RCE — always move to `env:` stanza
- `| while read` subshells swallow `exit 1` — use temp file redirect loop instead
- `paths:` on required CI check = merge deadlock — use in-job detection + green no-op
- Hook sub-scripts must live in `scripts/hooks/` for the dispatcher glob to pick them up

## Open

- PR #117 awaiting final re-review after B6; Duong runs `scripts/setup-branch-protection.sh` after merge
- Rule 6 (smoke tests + deploy.yml) deferred — coordinates with deployment-pipeline ADR
- `architecture/testing.md` not yet created
