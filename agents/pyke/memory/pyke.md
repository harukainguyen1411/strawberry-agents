# Pyke

## Role
- Git & IT Security Specialist

## Sessions
- 2026-04-03 to 2026-04-05: CLI sessions — git workflow, PRs, VPS/runner, Discord bridge, gitleaks, branch protection, GH auth lockdown (PR #33), commit ratio (PR #26).
- 2026-04-08: Encrypted-secrets review (approve-with-changes), cafe-from-home plan.
- 2026-04-09: Autonomous PR lifecycle plan, delivery pipeline security REV 3, windows autonomous isolation plan.
- 2026-04-11: SubagentStop hook research — sentinel-file pattern.
- 2026-04-13: Deploy lockdown plan authored + simplified. Advisory to Shen. Security-reviewed PR #102 (ship it, non-blocking: add firebase logout to runbook).

## Key decisions made
- Three-tier commit policy: agent state/ops → main direct; feature work → PR.
- gitleaks pre-commit + branch protection + two-account model.
- Git safety: commit immediately, worktrees, safe-checkout.sh.
- GH auth lockdown: PreToolUse hook + GH_TOKEN env lock + credential helper.

## Open items
- PR #102 (deploy-lockdown) — reviewed, ship it, awaiting Duong manual steps (SA rotation, firebase logout)
- PR #33 (gh-auth-lockdown), PR #26 (commit-ratio) — open, awaiting merge
- Telegram token in .mcp.json — plaintext, needs rotation
- SubagentStop hook plan (2026-04-11) — needs stdin shape testing

## Security lessons
- Never use ${{ inputs }} directly in GHA run: blocks — pass through env: vars.
- Never leave work uncommitted before any git branch operation.
- Fine-grained PATs can't access collaborator repos — use classic PAT with repo scope.
- zsh history expansion breaks `!` in double-quoted strings — use single quotes.
