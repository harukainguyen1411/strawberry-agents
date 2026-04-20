---
date: 2026-04-16
topic: GCP Secret Manager setup for Demo Studio 5-service architecture
---

# Secret Manager Setup — Demo Studio v3 (5-service)

## Current state

All secrets are plain env vars on Cloud Run, including `ANTHROPIC_API_KEY` which already exists in Secret Manager but is not wired. Service account is `demo-runner-sa@mmpt-233505.iam.gserviceaccount.com`.

---

## Q1: One secret or separate secrets per service?

**One secret per logical key, shared across services via Secret Manager references.**

Not one secret per service, not one giant blob. Each key gets its own Secret Manager entry. Services reference only the secrets they need. This gives clean rotation (rotate one secret, only services that use it are affected) without the overhead of per-service copies.

---

## Q2: Naming convention

Use `demo-studio-` prefix for all new secrets. Consistent, easy to filter, avoids collisions with existing project secrets.

| Secret Manager name | Value | Used by |
|---|---|---|
| `demo-studio-internal-secret` | shared inter-service bearer token | S1–S5 |
| `demo-studio-session-secret` | cookie signing key | S1 only |
| `demo-studio-mcp-token` | MCP server auth token | S1 + demo-studio-mcp |
| `demo-studio-anthropic-api-key` | Anthropic API key | S1 (or S3 if factory calls Claude directly) |
| `demo-studio-ws-api-key` | Wallet Studio API key | S1 |
| `demo-studio-firecrawl-api-key` | Firecrawl (remove after worker refactor) | S1 (temporary) |

**Do not create** per-service copies of `demo-studio-internal-secret`. All 5 services reference the same secret.

**Existing secrets to reuse (already in Secret Manager):**
- `ANTHROPIC_API_KEY` — already exists; rename or alias is not needed, just wire it to Cloud Run. But prefer creating `demo-studio-anthropic-api-key` as a new version pointing to the same value, to maintain naming consistency and avoid impacting other services that might reference the old name.

---

## Q3: Cloud Run `--set-secrets` syntax

Each secret is mounted as an env var. The Cloud Run revision reads the secret value at startup.

```bash
gcloud run services update demo-studio \
  --project mmpt-233505 \
  --region europe-west1 \
  --set-secrets \
INTERNAL_SECRET=demo-studio-internal-secret:latest,\
SESSION_SECRET=demo-studio-session-secret:latest,\
DEMO_STUDIO_MCP_TOKEN=demo-studio-mcp-token:latest,\
ANTHROPIC_API_KEY=demo-studio-anthropic-api-key:latest,\
WS_API_KEY=demo-studio-ws-api-key:latest
```

For the other 4 services (once deployed), they reference only what they need:

```bash
# S2, S3, S4, S5 — minimal example
gcloud run services update demo-config-mgmt \
  --project mmpt-233505 \
  --region europe-west1 \
  --set-secrets INTERNAL_SECRET=demo-studio-internal-secret:latest
```

**Use `:latest` not a version number.** This means rotation (adding a new secret version) takes effect on next Cloud Run revision deploy without changing the `--set-secrets` flag.

---

## Q4: IAM — which service accounts need secretAccessor?

All 5 services use `demo-runner-sa@mmpt-233505.iam.gserviceaccount.com` (confirmed from `demo-studio` service describe). Grant `roles/secretmanager.secretAccessor` on each secret individually, not at the project level.

```bash
# Grant for each secret — repeat for all demo-studio-* secrets
gcloud secrets add-iam-policy-binding demo-studio-internal-secret \
  --project mmpt-233505 \
  --member serviceAccount:demo-runner-sa@mmpt-233505.iam.gserviceaccount.com \
  --role roles/secretmanager.secretAccessor
```

If all 5 services use the same SA (likely for a prototype), one grant per secret covers all of them. If services ever get dedicated SAs, tighten to per-service grants.

**Do not grant at project level** (`--resource-type project`) — that would give the SA access to all secrets in the project including unrelated ones.

---

## Q5: Rotation without downtime

Secret Manager versioning makes rotation safe.

**Procedure:**
1. Generate new value: `python3 -c "import secrets; print(secrets.token_urlsafe(32))"`
2. Add a new version to the existing secret:
   ```bash
   echo -n "NEW_VALUE" | gcloud secrets versions add demo-studio-internal-secret \
     --project mmpt-233505 --data-file -
   ```
3. Deploy a new Cloud Run revision on all services (triggers secret re-read):
   ```bash
   gcloud run services update demo-studio --project mmpt-233505 --region europe-west1 \
     --set-env-vars _ROTATE=1
   ```
   (Setting a dummy env var forces a new revision. Remove it on the next real deploy.)
4. Verify services are healthy.
5. Disable the old secret version:
   ```bash
   gcloud secrets versions disable <old-version-number> \
     --secret demo-studio-internal-secret --project mmpt-233505
   ```

**For `INTERNAL_SECRET` specifically:** brief window during rolling deploy where old and new revisions coexist. During this window, the old revision still uses the old token value (loaded at startup). This means inter-service calls from a new-revision instance to an old-revision instance will 403 briefly. For a prototype, this is acceptable. If needed, add a grace period by keeping both old and new token valid simultaneously (read both from env, accept either) — but this is over-engineering for now.

**For `SESSION_SECRET`:** rotating this invalidates all active user sessions (existing cookies become invalid). Users get logged out. Warn before rotating.

---

## Q6: Which secrets to migrate now?

**Migrate now (high value, low effort):**
- `INTERNAL_SECRET` — new secret, create fresh
- `SESSION_SECRET` — new secret, create fresh
- `ANTHROPIC_API_KEY` — already in Secret Manager, just wire it
- `WS_API_KEY` / `WALLET_STUDIO_API_KEY` — same value, one secret
- `DEMO_STUDIO_MCP_TOKEN` — new secret, create fresh

**Leave as plain env vars for now (non-secret config):**
- `MANAGED_AGENT_ID`, `MANAGED_ENVIRONMENT_ID`, `MANAGED_VAULT_ID` — IDs, not credentials
- `FIRESTORE_PROJECT_ID`, `FIRESTORE_DATABASE` — non-sensitive config
- `COOKIE_SECURE` — boolean flag
- `BASE_URL`, `WALLET_STUDIO_BASE_URL` — non-sensitive URLs

**Remove after worker refactor:**
- `FIRECRAWL_API_KEY` — delete from Cloud Run and revoke at Firecrawl

---

## Q7: Local dev access

Developers pull secrets from Secret Manager on demand using `gcloud`. They should never commit secret values.

```bash
# Pull all demo-studio secrets into a local .env file (run once to set up, re-run to rotate)
gcloud secrets versions access latest --secret demo-studio-internal-secret \
  --project mmpt-233505 | xargs -I{} echo "INTERNAL_SECRET={}" >> .env.local

gcloud secrets versions access latest --secret demo-studio-session-secret \
  --project mmpt-233505 | xargs -I{} echo "SESSION_SECRET={}" >> .env.local

# etc. for each secret
```

Or create a `scripts/pull-secrets.sh` script that wraps all the above into one command. `.env.local` is gitignored.

**Prerequisite:** developer must have `roles/secretmanager.secretAccessor` on the project (or per-secret). Grant via:
```bash
gcloud projects add-iam-policy-binding mmpt-233505 \
  --member user:DEVELOPER_EMAIL \
  --role roles/secretmanager.secretAccessor
```

For CI/CD (when it exists): use Workload Identity or a dedicated CI service account, not a developer's personal credentials.

---

## Implementation order for Ekko

1. Create secrets in Secret Manager:
   ```bash
   # Create with value piped in
   python3 -c "import secrets; print(secrets.token_urlsafe(32), end='')" | \
     gcloud secrets create demo-studio-internal-secret --project mmpt-233505 --data-file -
   # Repeat for each secret listed in Q2
   ```
2. Grant `secretAccessor` to `demo-runner-sa` on each secret (see Q4)
3. Update `demo-studio` Cloud Run service with `--set-secrets` (see Q3), removing the plain env vars for the migrated keys
4. Verify deploy: `gcloud run services describe demo-studio --project mmpt-233505 --region europe-west1`
5. Run smoke test: `scripts/smoke-test.sh https://demo-studio-266692422014.europe-west1.run.app`
6. Repeat for S2–S5 when they are deployed, wiring only the secrets each service needs
