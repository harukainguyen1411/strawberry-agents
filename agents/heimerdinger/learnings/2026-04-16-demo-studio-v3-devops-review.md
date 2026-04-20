---
date: 2026-04-16
topic: Demo Studio v3 DevOps review for worker system refactor
---

# Demo Studio v3 — DevOps Review: Worker Refactor

## 1. Worker Infrastructure Footprint

**Workers are purely in-process asyncio tasks. No external infrastructure.**

Evidence:
- `main.py:2643` — workers are spawned via `asyncio.create_task(_run_dispatch())`
- `workers/base.py` — `_worker_tasks` is a plain Python dict (in-memory registry)
- No Pub/Sub, Cloud Tasks, Cloud Scheduler, or separate Cloud Run jobs exist in the config snapshot
- No Cloud Run Jobs defined (only two services: `demo-studio` and `demo-studio-mcp`)
- No message queue dependencies in `requirements.txt`

Killing the worker system is a code-only change. No GCP resources need to be deleted or modified.

## 2. Env Vars and Secrets Tied to Workers

None of the env vars in the Cloud Run config snapshot are worker-specific. All current vars serve the Managed Agent, auth, or external APIs:

| Var | Purpose | Keep? |
|---|---|---|
| `ANTHROPIC_API_KEY` | Used by workers AND the Managed Agent | Keep — Managed Agent still needs it |
| `MANAGED_AGENT_ID` | Managed Agent (not workers) | Keep |
| `MANAGED_ENVIRONMENT_ID` | Managed Agent | Keep |
| `MANAGED_VAULT_ID` | Managed Agent | Keep |
| `FIRESTORE_PROJECT_ID` | Session storage | Keep |
| `SESSION_SECRET` | Cookie auth | Keep |
| `INTERNAL_SECRET` | Internal API auth | Keep |
| `COOKIE_SECURE` | Auth | Keep |
| `BASE_URL` | Self-reference | Keep |
| `WS_API_KEY` / `WALLET_STUDIO_API_KEY` | Wallet Studio integration | Keep |
| `DEMO_STUDIO_MCP_TOKEN` | MCP server auth | Keep |
| `FIRECRAWL_API_KEY` | Research worker | **Remove after workers deleted** |
| `WALLET_STUDIO_BASE_URL` | Wallet Studio API | Verify if still used post-refactor |

**Only `FIRECRAWL_API_KEY` is worker-exclusive.** The `firecrawl-py` package in `requirements.txt` is also worker-only and should be removed along with the env var.

## 3. Deployment Scripts and CI/CD

**No CI/CD pipeline exists.** Deployment is manual via `gcloud run deploy --source`.

Scripts to review after refactor:
- `scripts/validate-env.sh` — validates env vars on startup. Currently checks: `ANTHROPIC_API_KEY`, `MANAGED_AGENT_ID`, `MANAGED_ENVIRONMENT_ID`, `FIRESTORE_PROJECT_ID`, `INTERNAL_SECRET`, `SESSION_SECRET`. No worker-specific vars are checked here — no changes needed unless `FIRECRAWL_API_KEY` was added later.
- `scripts/smoke-test.sh` — tests `/health`, `/debug`, `/session`, auth flow, static assets, `/dashboard`. No worker endpoints are tested. No changes needed.
- `scripts/run-backend.sh` / `scripts/run-dashboard.sh` / `scripts/watch-tests.sh` — local dev scripts, no worker references expected.

Worker-related endpoints to remove from `main.py` (not scripts):
- `GET /session/{id}/worker-status`
- `POST /session/{id}/dispatch` (or equivalent dispatch trigger)

## 4. Other DevOps Concerns

**Cloud Run timeout (300s):** Workers were the likely reason for the 5-minute timeout. Once workers are removed, the longest operations will be Managed Agent calls. 300s should remain sufficient but worth monitoring.

**Memory (512Mi):** Workers ran Claude API calls concurrently (up to 5 workers per session). After removal, peak memory usage will drop. 512Mi is safe to keep; could potentially be lowered but not a priority.

**`FIRECRAWL_API_KEY` secret rotation:** After removing the research worker, revoke this API key. It's an external service key and should not stay active unused.

## Risk Rating

**Low.** The worker system has zero external infrastructure footprint. Removing it requires:
1. Deleting Python files in `workers/` and tests
2. Removing worker-related endpoints and logic from `main.py`
3. Removing `firecrawl-py` from `requirements.txt` and `FIRECRAWL_API_KEY` from Cloud Run env vars
4. Redeploying via `gcloud run deploy --source`

No GCP resources to delete. No DNS changes. No service dependencies. Rollback is a redeploy of the previous image revision (Cloud Run keeps revision history).
