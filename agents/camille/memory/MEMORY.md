## Migrated from pyke (2026-04-17)
# Pyke

## Role
- Git & IT Security Specialist

## Sessions
- 2026-04-03 to 2026-04-05: CLI sessions — git workflow, PRs, VPS/runner, Discord bridge, gitleaks, branch protection, GH auth lockdown (PR #33), commit ratio (PR #26).
- 2026-04-08: Encrypted-secrets review (approve-with-changes), cafe-from-home plan.
- 2026-04-09: Autonomous PR lifecycle plan, delivery pipeline security REV 3, windows autonomous isolation plan.
- 2026-04-11: SubagentStop hook research — sentinel-file pattern.
- 2026-04-13: Deploy lockdown plan authored + simplified. Advisory to Shen. Security-reviewed PR #102 (ship it, non-blocking: add firebase logout to runbook).
- 2026-04-14: Git hygiene automation plan — worktree reaper, heartbeat check, end-subagent-session cleanup, pre-commit artifact guard.

## Key decisions made
- Three-tier commit policy: agent state/ops → main direct; feature work → PR.
- gitleaks pre-commit + branch protection + two-account model.
- Git safety: commit immediately, worktrees, safe-checkout.sh.
- GH auth lockdown: PreToolUse hook + GH_TOKEN env lock + credential helper.

## Open items
- PR #102 (deploy-lockdown) — reviewed, ship it, awaiting Duong manual steps (SA rotation, firebase logout)
- PR #33 (gh-auth-lockdown), PR #26 (commit-ratio) — open, awaiting merge
- Telegram token in .mcp.json — plaintext, needs rotation
- 2026-04-14: git-status-cleanup plan proposed — one-time cleanup of 10 merged worktrees, gitignore gaps, uncommitted UBCS work
- 2026-04-14: git-hygiene-automation plan proposed — worktree reaper script, heartbeat integration, end-subagent-session cleanup, pre-commit artifact check, gitignore gaps

## Security lessons
- Never use ${{ inputs }} directly in GHA run: blocks — pass through env: vars.
- Never leave work uncommitted before any git branch operation.
- Fine-grained PATs can't access collaborator repos — use classic PAT with repo scope.
- zsh history expansion breaks `!` in double-quoted strings — use single quotes.
## Migrated from shen (2026-04-17)
# Shen

## Identity
Git & IT Security Engineer in Duong's personal agent system (Strawberry). Executes security plans designed by Pyke.

## Role
Implementation agent for git workflows, security hardening, credential management, hooks, and infrastructure security. Sonnet-tier — always works from an approved plan file.

## Key Context
- Created 2026-04-05. Paired with Pyke (Opus, planner) — Pyke designs, Shen implements.
- Never self-designs. Always follows plan files from plans/approved/ or plans/in-progress/.
- Security domain: git hooks, GitHub auth, credential guards, audit trails, branch protection.

## Sessions
- 2026-04-09 (Commit 8, subagent): Executed protocol-migration Commit 8. Ported Agent Attribution, Review Protocol, and Git Safety — Shared Working Directory from root GIT_WORKFLOW.md into architecture/git-workflow.md. Removed stale "Canonical reference" trailing line. git rm'd GIT_WORKFLOW.md + scripts/migrate-ops.sh. Updated architecture/system-overview.md file tree. Commit 8d41ed0, pushed to main.
- 2026-04-13 (deploy-lockdown, subagent): Executed deploy-lockdown plan. Deleted secrets/firebase-hosting-sa-myapps.json and secrets/firebase-service-account.json. Zero SA keys remain under ~. Wrote architecture/deploy-runbook.md. PR #102 open. Plan promoted to implemented. Manual steps (SA rotation, gh secret set, firebase logout) listed in PR for Duong.

## Operational Notes
- System hooks (PreToolUse) are now active in .claude/settings.json — gh-auth-guard.sh blocks auth switching patterns.
- Writing CI workflow files containing `git rebase` or `--force-with-lease` triggers the system's own write protection hook. Need explicit approval for such files.
- Use `scripts/safe-checkout.sh` for existing branches; use `git worktree add -b` for new branches.

## Feedback
- If Evelynn over-specifies a delegation with too many instructions, do not follow the instructions too tightly. Trust your own skills and docs first — if you can find the relevant skill or documentation, use that as your guide instead.