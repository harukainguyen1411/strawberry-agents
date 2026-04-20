---
date: 2026-04-16
topic: Inter-service bearer token auth design for 5-service Demo Studio architecture
---

# Inter-service Auth Design — Demo Studio v3 (5-service)

## Architecture Overview

5 Cloud Run services in `mmpt-233505`, `europe-west1`:
- S1: `demo-studio` — orchestrator, serves studio UI
- S2: `demo-config-mgmt` — config read/write
- S3: `demo-factory` — content generation
- S4: `demo-verification` — pass verification
- S5: `demo-preview` — pass preview (iframe target)

## Decision: All services use "Allow unauthenticated" + app-level bearer token

Do **not** use Cloud Run IAM auth (the 403 you're seeing now). Reasons:
- IAM auth requires GCP service accounts and token exchange, adding complexity without benefit for internal services
- App-level tokens are simpler, testable without GCP, and consistent with the existing `INTERNAL_SECRET` pattern
- All 5 services are already in the same trust boundary (same project, same VPC-equivalent)

Each service: Cloud Run IAM = `allUsers → roles/run.invoker` (public), auth enforced by the app via `X-Internal-Secret` header check.

---

## Q1: One shared token or per-service tokens?

**Recommendation: One shared token (`INTERNAL_SECRET`) for all inter-service calls.**

Rationale:
- The existing `demo-studio` already uses `INTERNAL_SECRET` for this purpose — extend the same pattern
- Per-service tokens add rotation complexity (5 secrets instead of 1) without meaningful security gain when all services are in the same trust boundary
- If one token is compromised, all services are already reachable (same network) — per-service tokens don't change the blast radius

Trade-off acknowledged: a single token means any service can call any other. This is acceptable for this architecture. If services are ever exposed to different trust zones, revisit.

---

## Q2: Preview iframe auth

iframes cannot send custom headers, so `X-Internal-Secret` won't work for S5 (`demo-preview`).

**Recommendation: Make preview endpoints unauthenticated at the app level.**

The preview is rendering a visual pass — it contains no secrets and reveals no config data that isn't already visible in the studio UI. It does not need to be protected from public access.

Implementation:
- Set Cloud Run IAM to `allUsers → roles/run.invoker` (same as other services)
- Do **not** apply `X-Internal-Secret` check to preview render endpoints
- Optionally scope preview URLs to session ID (already part of the URL path) to prevent enumeration — but this is cosmetic, not a security control

If you want harder isolation later: issue a short-lived signed URL token (same pattern as the existing one-time session tokens in `auth.py`) and embed it in the iframe `src`. But this is not needed now.

---

## Q3: Cloud Run IAM vs app-level token

**Use `allUsers` (unauthenticated) on all 5 services + app-level `X-Internal-Secret`.**

Do not mix IAM auth and bearer tokens — it creates two auth layers to debug. App-level tokens are sufficient and match what already exists.

Exception: The Cloud Run services should still require HTTPS (Cloud Run enforces this by default).

---

## Q4: Dashboard calling `/logs` on all services

The dashboard on S1 calls `/logs` (or equivalent) on S2–S5. This is a server-side call (S1 backend → S2–S5 backends), so `X-Internal-Secret` works fine.

Pattern:
```python
headers = {"X-Internal-Secret": os.environ["INTERNAL_SECRET"]}
response = httpx.get(f"{SERVICE_URL}/logs", headers=headers)
```

Each service URL is injected via env var (see naming convention below). The dashboard itself is user-facing and uses the session cookie auth, not `X-Internal-Secret`.

---

## Q5: Env var naming convention

All services share `INTERNAL_SECRET` (the shared bearer token). Each service that calls another injects the target URL as an env var.

### Shared across all services
```
INTERNAL_SECRET         — shared bearer token for inter-service calls
FIRESTORE_PROJECT_ID    — GCP project ID
FIRESTORE_DATABASE_ID   — Firestore database name (demo-studio-staging)
```

### S1 (demo-studio) — knows about all downstream services
```
CONFIG_MGMT_URL         — URL of S2
FACTORY_URL             — URL of S3
VERIFICATION_URL        — URL of S4
PREVIEW_URL             — URL of S5
```

### S2 (demo-config-mgmt)
No downstream service URLs needed.

### S3 (demo-factory)
```
CONFIG_MGMT_URL         — calls S2 to read/write config
```

### S4 (demo-verification)
```
CONFIG_MGMT_URL         — calls S2 to read config
FACTORY_URL             — may call S3 to trigger regeneration
```

### S5 (demo-preview)
```
CONFIG_MGMT_URL         — calls S2 to read config for rendering
```

### Auth header convention (consistent across all services)
```
Header name: X-Internal-Secret
Value: Bearer {INTERNAL_SECRET}    ← or just the raw token, matching demo-studio's existing pattern
```

**Match the existing pattern exactly.** Current `auth.py:verify_internal_secret` reads `X-Internal-Secret` as a raw value (no "Bearer " prefix). Keep it that way — don't add the prefix unless you change all services simultaneously.

---

## Q6: Token rotation plan

`INTERNAL_SECRET` is set as a Cloud Run env var. Rotation is manual (no Secret Manager wired up yet).

**Rotation procedure:**
1. Generate new token: `python3 -c "import secrets; print(secrets.token_urlsafe(32))"`
2. Update all 5 Cloud Run services simultaneously: `gcloud run services update <name> --update-env-vars INTERNAL_SECRET=<new> --project mmpt-233505 --region europe-west1`
3. Cloud Run does a zero-downtime rolling deploy — brief window where old and new revisions both serve traffic. During this window, in-flight requests with the old token will get 403s. Acceptable for an internal tool.
4. No Firestore data to rotate — `INTERNAL_SECRET` is stateless.

**Recommended: migrate to Secret Manager** after the refactor stabilizes. Then rotation is: update the secret version, all services pick it up on next restart (or immediately if you mount as env via Secret Manager). This eliminates the "update 5 services" step.

---

## Implementation checklist (for Ekko)

- [ ] Create a shared `verify_internal_secret(request)` utility (copy from `demo-studio/auth.py`) in each new service
- [ ] Apply it as a FastAPI dependency on all non-preview endpoints
- [ ] Leave preview render endpoints unauthenticated
- [ ] Set `allUsers → roles/run.invoker` on all 5 Cloud Run services
- [ ] Add `INTERNAL_SECRET` env var to all 5 services (same value)
- [ ] Add `*_URL` env vars to services that call downstream (see Q5 above)
- [ ] For local dev: add all vars to `.env.example` with placeholder values

## Test targets (for Vi)

- `verify_internal_secret` returns True for correct header, False for wrong/missing
- Each protected endpoint returns 403 with wrong token, 200/201 with correct token
- Preview endpoints return 200 with no auth header
- Dashboard `/logs` aggregation passes `X-Internal-Secret` on server-side calls
