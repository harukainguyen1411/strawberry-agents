# Post-deploy Observation Report — Azir Option A
**Date:** 2026-04-21
**Executor:** Ekko
**Runbook:** `assessments/ship-day-azir-option-a-checklist-2026-04-21.md`
**Deploy sequence:** S5 → S3 → S1

---

## Deploy summary

| Service | PREV_REVISION | Source deploy revision | Active revision (with flags) | Status |
|---|---|---|---|---|
| S5 demo-preview | demo-preview-00005-ktj | demo-preview-00006-57w | demo-preview-00006-57w | DEPLOYED |
| S3 demo-factory | demo-factory-00005-dvs | demo-factory-00006-zql | demo-factory-00007-qjd | DEPLOYED |
| S1 demo-studio | demo-studio-00014-fc5 | demo-studio-00015-24z | demo-studio-00016-5rw | DEPLOYED |

Notes:
- S3 active revision is one step ahead of source deploy because `PROJECTS_FIRESTORE=1` was applied via `gcloud run services update` (creates new revision per GCR semantics).
- S1 active revision is similarly one step ahead: `MANAGED_AGENT_MCP_INPROCESS=1` and `S5_BASE` applied post-deploy.

## Service URLs

| Service | URL |
|---|---|
| S5 demo-preview | https://demo-preview-4nvufhmjiq-ew.a.run.app |
| S3 demo-factory | https://demo-factory-4nvufhmjiq-ew.a.run.app |
| S1 demo-studio | https://demo-studio-4nvufhmjiq-ew.a.run.app |

## Flags confirmed

| Service | Flag | Value |
|---|---|---|
| S1 | MANAGED_AGENT_MCP_INPROCESS | 1 |
| S1 | S5_BASE | https://demo-preview-4nvufhmjiq-ew.a.run.app |
| S3 | PROJECTS_FIRESTORE | 1 |

## Preflight blockers (pre-PR-#63)

Both blockers cleared by PR #63 (merged before this deploy session):
- G7: S3/S5 `deploy.sh` uppercase secret names corrected
- G4: `google-cloud-firestore>=2.19.0` added to `demo-factory/requirements.txt`

B3 MCP handshake smoke: cleared by Duong manually.

## Quota project issue

`billing/quota_project` was set to `myapps-b31ea` — caused a 403 on first S5 deploy attempt. Fixed: `gcloud config set billing/quota_project mmpt-233505`. Root cause: prior session left a stale ADC quota project override. Recovery was instant.

## Smoke results

### S5 smoke (§3.1)
- `/v1/preview/test-session` → HTTP 200, valid HTML ✓
- `/v1/preview/test-session/fullview` → HTTP 200, valid HTML ✓
- No `/healthz` route on S5 — runbook's `__healthz__` probe is aspirational (non-existing session ID returns 200 with empty content, not 404 — the service handles unknown session IDs gracefully)
- Verdict: GREEN

### S3 smoke (§3.2)
- `/build/test-id` → HTTP 401 (correct auth error, service alive) ✓
- Application startup complete, no import errors ✓
- No Firestore import errors on startup ✓
- Verdict: GREEN (application-level smoke blocked by FACTORY_TOKEN Rule 6 constraint — see note)

Note: Full `POST /build` and `GET /build/{id}` smoke requires FACTORY_TOKEN which is a secret. Per Rule 6, Ekko cannot read it into context. The 401 response confirms the service is alive and the auth layer is working. Duong should run a FACTORY_TOKEN-authenticated build smoke manually.

### S1 smoke
- `/` → HTTP 200, HTML ✓
- `/session/new` → HTTP 401 (expected without session cookie) ✓
- `/mcp` → HTTP 307 → `/mcp/` → HTTP 401 (route exists, auth working) ✓
- `/session/test-session-id/logs` → HTTP 401 (expected without session cookie) ✓
- No startup errors in Cloud Logging ✓
- Verdict: GREEN (Caitlyn 8-scenario suite requires live session — Duong to run manually)

## §4 Metrics snapshot (T+0 — just deployed, no traffic yet)

| Metric | Value | Threshold | Status |
|---|---|---|---|
| S1 errors/5min | 0 | ≤10 | OK |
| S3 errors/5min | 0 | ≤10 | OK |
| S5 errors/5min | 0 | ≤10 | OK |
| S3→S4 triggered/failed | 0/0 | failure <5% | N/A (no traffic) |
| MCP in-process init/err | 0/0 | err rate <1% | N/A (no traffic) |
| S4 poller terminal/timeout | 0/0 | timeout <5% | N/A (no traffic) |

Observation: all three services at zero errors post-deploy. No traffic yet — metrics will populate with first real session.

## Remaining manual steps (Duong)

1. **FACTORY_TOKEN-authenticated S3 smoke** — `POST /build`, `GET /build/{id}`, Firestore write log check.
2. **Caitlyn 8-scenario suite (§3.3)** — requires a full browser session with valid auth cookies.
3. **SSE `/logs` stream verification** — requires valid `ds_session` cookie from a live session.
4. **60-min observation** — set a reminder for T+60 and re-run §4 queries.
5. **ADR regression harness (Xayah)** — SE/BD/MAL/MAD green.

## Rollback positions

| Service | Rollback command |
|---|---|
| S1 flag flip | `gcloud run services update demo-studio --project=mmpt-233505 --region=europe-west1 --update-env-vars=MANAGED_AGENT_MCP_INPROCESS=0` |
| S3 flag flip | `gcloud run services update demo-factory --project=mmpt-233505 --region=europe-west1 --update-env-vars=PROJECTS_FIRESTORE=0` |
| S1 revision revert | `gcloud run services update-traffic demo-studio --project=mmpt-233505 --region=europe-west1 --to-revisions=demo-studio-00014-fc5=100` |
| S3 revision revert | `gcloud run services update-traffic demo-factory --project=mmpt-233505 --region=europe-west1 --to-revisions=demo-factory-00005-dvs=100` |
| S5 revision revert | `gcloud run services update-traffic demo-preview --project=mmpt-233505 --region=europe-west1 --to-revisions=demo-preview-00005-ktj=100` |

---
*Retirement sign-off (§6) pending — T+48h gate after clean burn-in. See runbook §6.*
