---
status: in-progress
owner: pyke
date: 2026-04-04
gdoc_id: 1CIoVy_FHMfhuG1B8l0ckR5d2SRdZ0Hi0irD_J0o5iT4
gdoc_url: https://docs.google.com/document/d/1CIoVy_FHMfhuG1B8l0ckR5d2SRdZ0Hi0irD_J0o5iT4/edit
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

### Step 5: Update agent-manager to inject token into agent sessions

**This is a Bard task.** The `launch_agent` function in `mcps/agent-manager/server.py` needs to inject `GH_TOKEN` and `GITHUB_TOKEN` into the iTerm session before launching Claude Code.

**Current behavior** (line ~380 in server.py):
```applescript
write text "cd {WORKSPACE} && claude"
```

**Required change:**
```applescript
write text "export GH_TOKEN=$(cat {WORKSPACE}/secrets/agent-github-token) && export GITHUB_TOKEN=$GH_TOKEN && cd {WORKSPACE} && claude"
```

This ensures:
- Every agent launched via `launch_agent` automatically authenticates as harukainguyen1411
- Both `gh` CLI and `git push` use the agent token
- The token is read from disk at launch time (not hardcoded)
- The token file path is `{WORKSPACE}/secrets/agent-github-token`

**Important:** The token must be set BEFORE `claude` starts, because Claude Code inherits the shell environment. Setting it after launch has no effect.

**Alternative (cleaner):** Read the token in Python and inject it:
```python
TOKEN_FILE = os.path.join(WORKSPACE, 'secrets', 'agent-github-token')
token = ''
if os.path.exists(TOKEN_FILE):
    with open(TOKEN_FILE) as f:
        token = f.read().strip()

if token:
    launch_cmd = f'export GH_TOKEN={token} GITHUB_TOKEN={token} && cd {WORKSPACE} && claude'
else:
    launch_cmd = f'cd {WORKSPACE} && claude'
```

This way, if the token file doesn't exist yet, agents still launch normally (with owner auth as fallback).

### Step 6: Evelynn MCP server must NOT use the agent token

**Critical:** The Evelynn MCP server (`mcps/evelynn/server.py`) runs `commit_agent_state_to_main`, which pushes directly to main. This MUST run as Duongntd (owner) to bypass branch protection.

**Ensure:**
- The evelynn MCP server's `start.sh` does NOT set `GH_TOKEN` or `GITHUB_TOKEN`
- It inherits Duong's default `gh auth` (which is Duongntd)
- If `GH_TOKEN` is set in the parent shell, the evelynn start script must explicitly `unset GH_TOKEN GITHUB_TOKEN`

**Check `mcps/evelynn/scripts/start.sh`** — if it sources any env file, make sure that file does not contain the agent token.

**Bard implementation checklist:**
1. Update `launch_agent` in `mcps/agent-manager/server.py` to inject `GH_TOKEN`/`GITHUB_TOKEN` from `secrets/agent-github-token`
2. Verify `mcps/evelynn/scripts/start.sh` does NOT have the agent token
3. Add `unset GH_TOKEN GITHUB_TOKEN` to `mcps/evelynn/scripts/start.sh` as a safety net
4. Test: launch an agent, run `echo $GH_TOKEN` — should show the agent token
5. Test: check evelynn MCP server env — should NOT have the agent token

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
