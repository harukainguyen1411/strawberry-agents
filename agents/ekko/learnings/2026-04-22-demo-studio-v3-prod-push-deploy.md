# 2026-04-22 — demo-studio-v3 prod push + redeploy

## What happened

Fast-mode push + deploy of `feat/demo-studio-v3` to Cloud Run prod.

- Branch: `feat/demo-studio-v3` (missmp/company-os), HEAD `7abd989`
- Pre-push hooks passed cleanly (TDD gate, commit-type gate — Viktor's test commits satisfied both)
- `deploy.sh` invoked with 4 legacy env vars (`BASE_URL`, `MANAGED_AGENT_ID`, `MANAGED_ENVIRONMENT_ID`, `MANAGED_VAULT_ID`) — these are schema-required by deploy.sh but not used by vanilla path post-hotfix
- Deploy wall time: ~229s (build + revision creation + traffic routing)
- New revision: `demo-studio-00024-dms`
- Smoke: HTTP 200, returns expected HTML

## Key facts

- `MANAGED_AGENT_MCP_INPROCESS` is NOT set by deploy.sh (Viktor stripped it in 45702a8) — vanilla path default
- gcloud project: `mmpt-233505`, region: `europe-west1`, service: `demo-studio`
- `.agent-ids.env` exists at `tools/demo-studio-v3/.agent-ids.env` (gitignored, local only)
- Previous revision (before this deploy) was `demo-studio-00023-*` range — new is `00024-dms`
