# Shen — Operational Memory

Last updated: 2026-04-17

## Sessions

- 2026-04-17: Implemented TDD hooks + CI (PR #117) from plan/tdd-workflow-rules; CLAUDE.md rules 12-17 + akali agent landed to main
- 2026-04-17: Fixed PR #117 blockers — hook dispatcher, CI RCE injection, subshell exit swallowing, e2e paths deadlock, fetch-depth; 7/7 tests green

## Key Knowledge

- Write calls fail with "file not read" on existing files — always Read before Write, even for new paths if unsure
- First Write after a diverged-main state may silently no-op; always merge origin/main before creating files
- `scripts/safe-checkout.sh` blocks on untracked files — commit or stage everything before calling it
- Agent definitions (.claude/agents/) go direct to main like plans; hook scripts + CI go through PR
- Bootstrap exemption for xfail-first: when implementing the TDD system itself, shell test harness substitutes for xfail test; document exemption in PR body

## Key Knowledge (additions)

- CI expression injection: never interpolate `${{ github.event.* }}` in `run:` blocks — always move to `env:` stanza and reference via `$ENV_VAR`
- `| while read` subshells swallow `exit 1` — use temp file + `while IFS= read -r < file` to keep exit codes in current shell (POSIX-portable)
- `paths:` filter on required CI checks causes permanent merge deadlock for out-of-path PRs — use in-job detection + green no-op instead
- git hook names must match the verb exactly (`pre-commit`, `pre-push`) — sub-hook files with different names never fire without a dispatcher

## Open

- PR #117 needs reviewer re-run then merge; Duong runs `scripts/setup-branch-protection.sh` after merge
- Rule 6 (smoke tests + deploy.yml) deferred — coordinates with deployment-pipeline ADR
- `architecture/testing.md` not yet created
