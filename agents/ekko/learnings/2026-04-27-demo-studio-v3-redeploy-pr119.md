# 2026-04-27 — demo-studio-v3 redeploy after PR #119 merge

## Context

PR #119 (`fix/pr32-runway-f1-f2`) was merged into `feat/demo-studio-v3`. Previous Ekko verified
merge and died (tmux substrate disappeared). This session was a clean background-subagent dispatch
to finish the redeploy.

## Steps taken

1. Fetched `origin/feat/demo-studio-v3` — HEAD advanced from `ab51372` to `b18eb112`. Matched required SHA exactly.
2. Fast-forward merged the main worktree (`company-os/`) to `b18eb112`. Working tree was clean; deploy.sh dirty-check passed.
3. Extracted required env vars (BASE_URL, MANAGED_AGENT_ID, MANAGED_ENVIRONMENT_ID, MANAGED_VAULT_ID) from the live service via `gcloud run services describe`.
4. Ran `deploy.sh` from `tools/demo-studio-v3/` with the four required env vars set.
5. Deploy completed in ~5 min. New revision: `demo-studio-00030-2zg`, 100% traffic.
6. Smoke probe: `GET /health` → 200 `{"status":"ok"}`.

## Key facts

- Previous revision (rollback target): `demo-studio-00029-8bk`
- New revision: `demo-studio-00030-2zg`
- deploy.sh does NOT read .env files — env vars must be set at call site
- deploy.sh dirty-check uses `git status --porcelain` from the repo root — the main worktree must be on the correct branch with clean tree
- No MANAGED_AGENT_MCP_INPROCESS needed in this deploy — not in the existing service env vars (removed in earlier session)

## Pattern for future redeploys

```
cd tools/demo-studio-v3/
BASE_URL="..." MANAGED_AGENT_ID="..." MANAGED_ENVIRONMENT_ID="..." MANAGED_VAULT_ID="..." bash deploy.sh
```
Then: `curl https://demo-studio-266692422014.europe-west1.run.app/health`
