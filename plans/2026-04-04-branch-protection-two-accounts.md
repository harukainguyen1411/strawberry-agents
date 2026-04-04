---
status: in-progress
owner: pyke
date: 2026-04-04
---

# Branch Protection — Two-Account Setup

## Problem

14 agents share one repo. Without enforcement, agents can (and do) push feature work directly to main, bypassing the PR workflow. Protocol rules alone are insufficient.

## Design

Two GitHub accounts with different permission levels:

| Account | Role | Main push | PR merge | Bypass protection |
|---|---|---|---|---|
| **Duongntd** (owner) | Tier 1/2 commits, commit_agent_state_to_main | Yes | Yes | Yes |
| **Second account** (collaborator) | All agent CLI sessions | No (blocked) | Yes (via PR) | No |

## What's Done

- [x] **Pre-push hook** — `.git/hooks/pre-push` blocks non-Tier-1/2 commits from being pushed to main. Checks commit message prefix (chore:/ops:/Merge:).
- [x] **Setup script** — `scripts/setup-branch-protection.sh` contains all commands for the remaining steps.
- [x] **Branch protection enabled** — Duong ran Step 1 of the setup script. Main now requires PRs (enforce_admins=false so owner can bypass).

## What's Remaining

### 1. Create second GitHub account
Duong creates a second GitHub account (or uses an existing alt). This account will be the identity for all agent CLI sessions.

### 2. Add as collaborator with push access
```bash
gh api repos/Duongntd/strawberry/collaborators/SECOND_ACCOUNT -X PUT \
  -H "Accept: application/vnd.github+json" -f permission=push
```

### 3. Create fine-grained personal access token
On the second account, create a token with:
- Repository access: `Duongntd/strawberry`
- Permissions: Contents (read/write), Pull requests (read/write)

### 4. Configure agent sessions to authenticate as second account
Options:
- **Environment variable:** Set `GH_TOKEN=<token>` in agent launch scripts
- **gh auth:** Run `gh auth login --with-token` in each agent's iTerm session
- **Git credential:** Configure git to use the second account's token for this repo

The agent launch script (`launch_agent` in agent-manager) should set `GH_TOKEN` so all spawned agents automatically authenticate as the second account.

### 5. Evelynn keeps owner auth
Evelynn's `commit_agent_state_to_main` tool runs as the owner account (Duongntd) since it needs bypass rights to push Tier 1/2 commits directly to main.

### 6. Enable auto-delete branches on merge
```bash
gh repo edit Duongntd/strawberry --delete-branch-on-merge
```

### 7. Delete stale merged branches
```bash
git push origin --delete feature/evelynn-mcp-and-flexible-conversations
git push origin --delete feature/contributor-pipeline
git push origin --delete feature/turn-based-conversations
git push origin --delete fix/migrate-ops-improvements
```

### 8. Verify
1. As second account: try pushing a `feat:` commit to main — should be rejected by GitHub
2. As second account: create a PR and merge — should work
3. As Duongntd: push a `chore:` commit to main — should succeed (owner bypass)

## Security Notes

- The second account's token should be stored in `secrets/` (gitignored) or as an environment variable — never in committed files
- If the token leaks, revoke and rotate immediately — it only has push access, not admin
- The pre-push hook is a convenience layer, not security — branch protection is the real enforcement
