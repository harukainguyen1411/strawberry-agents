---
status: proposed
owner: pyke
---

# Fix: Agent PRs Created Under Duong's Account Instead of harukainguyen1411

## Problem

Agent PRs (e.g. #26 by Pyke) are appearing under `Duongntd` instead of the agent account `harukainguyen1411`. This means agents are acting with Duong's identity on GitHub — a security and hygiene issue.

## Investigation Findings

### 1. `gh auth status` — harukainguyen1411 not present

```
github.com
  ✓ Duongntd (keyring) — ACTIVE
  ✓ duongntd99 (keyring)
```

`harukainguyen1411` is not registered in the gh CLI keyring at all. Agents fall through to the active keyring account (`Duongntd`).

### 2. Token injection — silent failure path

In `mcps/agent-manager/server.py`, `launch_agent` reads `secrets/agent-github-token` and injects `GH_TOKEN`/`GITHUB_TOKEN` env vars. But there is a **silent skip**:

```python
if st.st_mode & 0o077:
    log.warning(...)  # too open
else:
    use_token = True  # only inject if 600 exactly
```

If the file permissions are wider than 600, `use_token` stays `False` and agents launch **without token injection** — falling back to the active keyring account. This failure is silent from the agent's perspective.

### 3. Token setup was never completed

Per Pyke's memory and `plans/in-progress/2026-04-04-branch-protection-two-accounts.md`, Steps 3-9 of the harukainguyen1411 setup are pending:
- Token was never created under the `harukainguyen1411` GitHub account
- `secrets/agent-github-token` may contain a token, but its account ownership is unverified

### 4. Root cause — likely double failure

Most likely both issues are present:
- **Primary**: `secrets/agent-github-token` contains a token that is NOT for `harukainguyen1411` (possibly Duong's own PAT, created when testing)
- **Secondary**: File permissions may be wider than 600, causing silent injection skip

## Fix Steps

### Step 1 — Duong: Create harukainguyen1411 PAT (manual)
1. Log in to GitHub as `harukainguyen1411`
2. Go to Settings → Developer settings → Personal access tokens → Fine-grained tokens
3. Create token with scopes: `contents: write`, `pull-requests: write`, `metadata: read`
4. Repository access: `Duongntd/strawberry` only
5. Copy the token

### Step 2 — Duong: Write token to file with correct permissions (manual)
```sh
# Write token (replace TOKEN with actual value)
echo -n "TOKEN" > /path/to/strawberry/secrets/agent-github-token
chmod 600 /path/to/strawberry/secrets/agent-github-token
```

### Step 3 — Verify token injection works
After writing the token, launch an agent and verify:
```sh
# In the agent session, check:
gh auth status   # should show harukainguyen1411 via GH_TOKEN
gh api user --jq '.login'   # should return harukainguyen1411
```

### Step 4 — Add logging to launch_agent for token skip (optional hardening)
Consider surfacing the token-skip event to the launching agent's inbox so the failure isn't silent. This is a low-priority improvement.

### Step 5 — Confirm harukainguyen1411 is a collaborator
Verify that `harukainguyen1411` has been added as a collaborator to `Duongntd/strawberry` with write access. Without this, the PAT won't be able to push branches or create PRs.
```sh
gh api repos/Duongntd/strawberry/collaborators --jq '.[].login'
```

## Notes

- The two-account model is the right design: `Duongntd` (owner, branch protection bypass) + `harukainguyen1411` (agent account, PRs flow through protected branches). The mechanism exists — it just needs the correct token.
- `GH_TOKEN` env var takes precedence over `gh` keyring auth when set — so once the correct token is in place and permissions are 600, injection will work without any code changes.
- `duongntd99` in the keyring (inactive) is unrelated — likely a personal secondary account.
