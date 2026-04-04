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

## What's Remaining — Step-by-Step (exact sequence matters)

### Step 1: Invite second account as collaborator (as Duongntd)

Must be done FIRST — the second account needs repo access before it can create a scoped token.

```bash
# Run as Duongntd (repo owner)
gh api repos/Duongntd/strawberry/collaborators/harukainguyen1411 -X PUT \
  -H "Accept: application/vnd.github+json" -f permission=push
```

### Step 2: Accept the invitation (as harukainguyen1411)

Log into github.com as harukainguyen1411 and accept the collaboration invitation. Either:
- Check email for the invitation link, or
- Go to https://github.com/Duongntd/strawberry — GitHub shows a banner to accept
- Or via API:

```bash
# Run as harukainguyen1411
gh api user/repository_invitations --jq '.[].id'
# Then accept with the invitation ID:
gh api user/repository_invitations/<INVITATION_ID> -X PATCH
```

### Step 3: Create fine-grained token (as harukainguyen1411)

Now that the account has repo access, it can create a scoped token:

1. Log into github.com as harukainguyen1411
2. Go to: Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token
3. Configure:
   - **Token name:** strawberry-agents
   - **Expiration:** 90 days (or custom)
   - **Resource owner:** harukainguyen1411
   - **Repository access:** Only select repositories → select `Duongntd/strawberry`
   - **Permissions:**
     - Contents: Read and write
     - Pull requests: Read and write
     - Metadata: Read (auto-selected)
4. Generate token and copy it

### Step 4: Store the token securely

```bash
# Save to gitignored secrets directory
mkdir -p secrets
echo "ghp_xxxxx" > secrets/agent-github-token
```

### Step 5: Configure agent sessions to use the token

Option A — Set in agent launch scripts (recommended):
```bash
# In the agent launch script or iTerm profile
export GH_TOKEN=$(cat ~/Documents/Personal/strawberry/secrets/agent-github-token)
export GITHUB_TOKEN=$GH_TOKEN
```

Option B — Configure git credential for this repo:
```bash
# Set the remote URL to include the token
git remote set-url origin https://harukainguyen1411:$(cat secrets/agent-github-token)@github.com/Duongntd/strawberry.git
```

Option A is cleaner — it works for both `gh` CLI and `git push` without modifying the remote URL.

### Step 6: Evelynn keeps owner auth

Evelynn's `commit_agent_state_to_main` tool must run as Duongntd (owner) since it needs bypass rights. Ensure the Evelynn MCP server environment does NOT have the agent token set — it should use the default `gh auth` which is Duongntd.

### Step 7: Enable auto-delete branches on merge

```bash
# Run as Duongntd
gh repo edit Duongntd/strawberry --delete-branch-on-merge
```

### Step 8: Delete stale merged branches

```bash
git push origin --delete feature/evelynn-mcp-and-flexible-conversations
git push origin --delete feature/contributor-pipeline
git push origin --delete feature/turn-based-conversations
git push origin --delete fix/migrate-ops-improvements
```

### Step 9: Verify

1. Set `GH_TOKEN` to the agent token in a terminal
2. Try `git push origin main` with a `feat:` commit → should be **rejected** by GitHub
3. Create a branch, push, create PR → should **succeed**
4. Unset `GH_TOKEN` (back to Duongntd)
5. Push a `chore:` commit to main → should **succeed** (owner bypass)

## Security Notes

- The second account's token should be stored in `secrets/` (gitignored) or as an environment variable — never in committed files
- If the token leaks, revoke and rotate immediately — it only has push access, not admin
- The pre-push hook is a convenience layer, not security — branch protection is the real enforcement
