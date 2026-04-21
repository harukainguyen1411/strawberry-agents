# Ship-day Secrets Audit — Azir God Plan v2 (Option A)

**Date:** 2026-04-21
**Concern:** work
**Author:** Heimerdinger (advisor — no execution, no decryption, no `age -d`)
**Companion:** `assessments/ship-day-azir-option-a-checklist-2026-04-21.md`
**GCP project:** `mmpt-233505`
**Scope:** secrets Duong must ensure are provisioned before `MANAGED_AGENT_MCP_INPROCESS=1`, `PROJECTS_FIRESTORE=1`, and `S5_BASE=...` flags go live on `mmpt-233505`.

---

## Summary — action items for Duong

**Count of NEW secrets Duong must create before flip: 0.**

Every env-var reference I found in Wave 2 code paths resolves to either (a) a secret already bound in the existing deploy.sh scripts or (b) a non-secret runtime config value (URLs, flag values). What Wave 2 introduces is **new consumers for existing secrets**, not new secrets.

Three things Duong should **verify** (not create):

1. `DS_STUDIO_MCP_TOKEN` exists in Secret Manager and `demo-runner-sa` has `roles/secretmanager.secretAccessor` on it. The secret is already referenced by S1's `secrets-mapping.txt`, but Karma's MCP-merge ADR reused the same token for the new in-process `/mcp` sub-route — confirm both producer (token owner) and consumer (S1) sides agree on the value. If the secret was ever rotated asymmetrically, the new sub-route will 401.
2. Both secret-name conventions exist side-by-side in Secret Manager: **uppercase_underscore** (`DS_SHARED_*`, `DS_STUDIO_*`, used by S1) AND **lowercase-hyphen** (`ds-shared-*`, `ds-*-token`, used by S3/S5). These are two different Secret Manager objects in the same project. If one convention's set is missing, the corresponding service will fail at deploy time.
3. `demo-factory` service account holds `roles/datastore.user` on the target Firestore database — this is IAM, not a secret-value, but it's blocking for `PROJECTS_FIRESTORE=1`.

No Duong-side .env edits. No `tools/decrypt.sh` invocation needed for this audit — I did not read any decrypted value.

---

## Methodology

- Read `os.environ` / `os.getenv` in every Python source file under the three service dirs.
- Read the three `deploy.sh` scripts and S1's `secrets-mapping.txt`.
- Cross-referenced Wave 1 (merged) and Wave 2 (PR #61, not yet merged) surface inventory from the plans.
- Listed `strawberry-agents/secrets/` directory (filenames only; no decryption).
- Did NOT call `age -d`, did NOT read plaintext secret values, did NOT run `gcloud secrets versions access`.

---

## Inventory — all secrets consumed in the v2 flow

### S1 — `demo-studio` (deploys from `tools/demo-studio-v3/`)

Bindings from `secrets-mapping.txt`:

| Env var | Secret Manager name | Already provisioned? | Wave 2 change? | Action for Duong |
|---|---|---|---|---|
| `ANTHROPIC_API_KEY` | `DS_SHARED_ANTHROPIC_API_KEY` | Yes (pre-existing) | None | None |
| `SESSION_SECRET` | `DS_STUDIO_SESSION_SECRET` | Yes | None. Signs the `ds_session` cookie used by the new SSE `/logs` endpoint (Phase F auth). | None — existing secret, new consumer path (SSE auth reuses cookie, ADR §Q1 pick (a)) |
| `INTERNAL_SECRET` | `DS_SHARED_INTERNAL_SECRET` | Yes | None on S1 side; watch G6 on S3 | None for S1. If S3 starts enforcing `X-Internal-Secret` after PR #61 merge, see S3 row below |
| `WS_API_KEY` | `DS_SHARED_WS_API_KEY` | Yes | None | None |
| `WALLET_STUDIO_API_KEY` | `DS_SHARED_WS_API_KEY` (alias) | Yes | None | None |
| `DEMO_STUDIO_MCP_TOKEN` | `DS_STUDIO_MCP_TOKEN` | Yes | **Reused by MCP-merge.** PR #59 made S1's `/mcp` sub-route validate this token. Value must match what the MCP client inside S1 presents on `Authorization: Bearer ...` for handshake. | **Verify:** value is consistent; `demo-runner-sa` has secretAccessor. |
| `FIRECRAWL_API_KEY` | `DS_STUDIO_FIRECRAWL_KEY` | Yes | None | None |
| `DEMO_SERVICE_TOKEN` | `DS_STUDIO_DEMO_SERVICE_TOKEN` | Yes | None | None |
| `CONFIG_MGMT_TOKEN` | `DS_CONFIG_MGMT_TOKEN` | Yes | None | None |

New S1 env vars introduced by Wave 2 (**none are secrets**):

| Env var | Type | Source | Purpose |
|---|---|---|---|
| `MANAGED_AGENT_MCP_INPROCESS` | flag (`0`/`1`) | set on `gcloud run services update` | Routes agent MCP traffic through in-process sub-route |
| `S5_BASE` | URL | set on `gcloud run services update` | S5 base URL for iframe + fullview |
| `VERIFICATION_POLL_TIMEOUT_S` | int (default 300) | optional env override | Phase G S4 poller timeout |
| `get_last_verification` | MCP resource name | in-process MCP server | Read-only; no auth surface beyond the existing MCP bearer |

### S3 — `demo-factory` (deploys from `tools/demo-factory/`)

Bindings from `deploy.sh` line 12:

| Env var | Secret Manager name | Already provisioned? | Wave 2 change? | Action for Duong |
|---|---|---|---|---|
| `FACTORY_TOKEN` | `ds-factory-token` | Assumed yes (deploy.sh references it) | Still load-bearing. Used on `POST /build` + `GET /build/{id}` + `POST /v1/build` auth. Any S1 call into S3 sends `Authorization: Bearer ${FACTORY_TOKEN}`. | **Verify** this secret exists under the lowercase-hyphen name (`ds-factory-token`, NOT `DS_FACTORY_TOKEN`) and `demo-factory` SA has secretAccessor |
| `ANTHROPIC_API_KEY` | `ds-shared-anthropic-api-key` | Assumed yes | None | Verify — note this is a **different** Secret Manager object from S1's `DS_SHARED_ANTHROPIC_API_KEY`. Same concept, two names (G7). |
| `WS_API_KEY` | `ds-shared-ws-api-key` | Assumed yes | None | Verify. Same G7 caveat. |

Wave 2 non-secret env vars on S3:

| Env var | Type | Source | Purpose |
|---|---|---|---|
| `PROJECTS_FIRESTORE` | flag (`0`/`1`) | set on deploy / update | Activates Firestore-backed projectId storage |

**Potential new S3 secret need — contingent on PR #61 content (G6):**

- If the S4 poll loop on S1 calls S3 (or S3 itself starts enforcing `X-Internal-Secret` on any new inbound route for the Wave 2 flow), then `INTERNAL_SECRET` must be added to `demo-factory/deploy.sh` `--set-secrets` line, bound to the same Secret Manager object S1 uses (`DS_SHARED_INTERNAL_SECRET`).
- Current HEAD of `tools/demo-factory/**/*.py`: **zero** `INTERNAL_SECRET` or `X-Internal-Secret` references. Action depends on what #61 adds.
- **Action for Duong:** after PR #61 merges, re-grep. If the surface appears, the secret object already exists (`DS_SHARED_INTERNAL_SECRET`) — no Duong action beyond ensuring the `demo-factory` SA has `roles/secretmanager.secretAccessor` on that object. Ekko patches `deploy.sh` to add the binding.

**IAM on S3 SA for Firestore (G4 — not a secret but blocking):**

| Resource | Required | Action for Duong |
|---|---|---|
| `demo-factory` SA has `roles/datastore.user` on Firestore DB used by `PROJECTS_FIRESTORE=1` | Yes | **Verify** via `gcloud projects get-iam-policy`. If absent, grant it (single `gcloud projects add-iam-policy-binding ...` call). This is IAM, not a secret. |
| `google-cloud-firestore` in `demo-factory/requirements.txt` | Yes | **Verify** — unrelated to secrets, but same blocking gate |

### S5 — `demo-preview` (deploys from `tools/demo-preview/`)

Bindings from `deploy.sh` line 12:

| Env var | Secret Manager name | Already provisioned? | Wave 2 change? | Action for Duong |
|---|---|---|---|---|
| `PREVIEW_TOKEN` | `ds-preview-token` | Assumed yes | None. Bearer on S5's `/logs` route (not on the iframe `/v1/preview/{id}` or `/fullview` routes, which are cookie-less per code inspection). Wave 2 iframe and fullview traffic is **browser-direct, no auth** — no S1→S5 credential required. | **Verify** secret exists and SA has secretAccessor. |
| `CONFIG_MGMT_TOKEN` | `ds-config-mgmt-token` | Assumed yes | None | Verify |

S5 runtime config (non-secret):

| Env var | Source | Purpose |
|---|---|---|
| `CONFIG_MGMT_URL` | `--set-env-vars` on deploy.sh | Upstream for preview HTML assembly |

**No new S5 secrets for Wave 2.** The iframe flow assumes the preview URL is reachable directly by the user's browser (no S1-mediated proxy) and uses no bearer. If Wave 2 ever decides to gate iframe traffic behind auth, S5 needs a cookie/bearer scheme — not in scope today per the ADR.

---

## Strawberry-agents `secrets/` directory — filename inventory (no decryption)

For completeness. These files are local to the strawberry-agents repo (gitignored) and unrelated to the Demo Studio Secret Manager inventory:

```
age-key.txt                             (age decryption key)
branch-protection-pre-rollout-strawberry-app.json
discord-bot-token.txt                   (Discord)
discord-webhook.txt                     (Discord)
encrypted/                              (directory)
README.md
recipients.txt                          (age recipients)
reviewer-auth-senna.env                 (agent)
reviewer-auth.env                       (agent)
```

None of these are Demo Studio ship-day blockers. Agent-side secrets (reviewer-auth*) and tooling (age-key) only.

---

## New secrets count by "must Duong create something new" criterion

| Category | Count |
|---|---|
| Brand-new secrets Duong must create for this ship | **0** |
| Existing secrets Duong must verify IAM on (`DS_STUDIO_MCP_TOKEN`, `DS_SHARED_INTERNAL_SECRET` if G6 triggers, lowercase-hyphen set if G7 missing) | 2-3 |
| IAM grants Duong must verify (datastore.user on demo-factory SA) | 1 |
| Secret rotations required | 0 |
| Secrets Duong may need to unify post-ship (advisory, non-blocking) | 1 family — `DS_SHARED_*` vs `ds-shared-*` (G7) |

---

## Recommended pre-ship command sequence for Duong / Ekko

Read-only verification only. No writes, no decryption. Safe to run anytime before ship.

```bash
PROJECT=mmpt-233505

# 1. All three naming conventions' secrets exist
gcloud secrets list --project=$PROJECT --format='value(name)' \
  | grep -iE '^(DS_(STUDIO|SHARED|CONFIG)_|ds-(shared|factory|preview|config-mgmt|studio)-)' | sort

# 2. demo-runner-sa has secretAccessor on DS_STUDIO_MCP_TOKEN
gcloud secrets get-iam-policy DS_STUDIO_MCP_TOKEN --project=$PROJECT \
  --flatten=bindings --filter='bindings.role:roles/secretmanager.secretAccessor' \
  --format='value(bindings.members)'

# 3. demo-factory SA has datastore.user (G4)
gcloud projects get-iam-policy $PROJECT --flatten='bindings[].members' \
  --filter='bindings.members~demo-factory AND bindings.role~datastore.user' \
  --format='value(bindings.role,bindings.members)'

# 4. DEMO_FACTORY_TEST_MODE NOT set on live demo-factory (G8)
gcloud run services describe demo-factory --project=$PROJECT --region=europe-west1 \
  --format='value(spec.template.spec.containers[0].env[].name)' | grep -F DEMO_FACTORY_TEST_MODE \
  && echo "LEAK" || echo OK

# 5. Firestore client lib in S3 requirements (G4)
grep -q '^google-cloud-firestore' \
  /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-factory/requirements.txt \
  && echo OK || echo MISSING

# 6. Post-#61 merge: INTERNAL_SECRET usage in S3 (G6)
grep -rnE "INTERNAL_SECRET|X-Internal-Secret" \
  /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-factory/ \
  --include="*.py" || echo "OK — S3 does not need INTERNAL_SECRET bound"
```

---

## Non-secrets, for completeness (will move around ship day)

These are deploy-time configuration values, **not** secrets. Listed so Duong does not accidentally think they need Secret Manager provisioning.

- `BASE_URL`, `MANAGED_AGENT_ID`, `MANAGED_ENVIRONMENT_ID`, `MANAGED_VAULT_ID` — exported before running `demo-studio-v3/deploy.sh`. Duong has these values from prior deploys; no action.
- `MANAGED_AGENT_MCP_INPROCESS`, `S5_BASE`, `PROJECTS_FIRESTORE`, `VERIFICATION_POLL_TIMEOUT_S` — set via `gcloud run services update --update-env-vars`. Plain text, no Secret Manager.
- `FIRESTORE_PROJECT_ID`, `FIRESTORE_DATABASE`, `COOKIE_SECURE`, `WALLET_STUDIO_BASE_URL`, `CONFIG_MGMT_URL`, `FACTORY_URL`, `VERIFICATION_URL`, `PREVIEW_URL`, `GCS_BUCKET`, `WS_BASE_URL`, `WS_ORG_ID`, `WS_TEMPLATE_ID` — deploy-time config.

---

## Recommendations (not actions)

1. **Unify S1/S3/S5 secret-name conventions** in a follow-up PR (post-ship). Pick one — uppercase_underscore is cleaner and matches GCP Secret Manager conventions. Requires creating lowercase-hyphen → uppercase_underscore aliases (or vice versa) via new `gcloud secrets create` + version copy, then patching `deploy.sh` files. Out of scope today.
2. **Grant `roles/secretmanager.secretAccessor` on `DS_SHARED_INTERNAL_SECRET` to `demo-factory` SA proactively,** even if PR #61 does not currently need it. Cheap preparation; reduces mid-ship patch risk.
3. **Document the Secret Manager inventory** (secret name → owner service → producer/rotator) as a follow-up to `architecture/secret-manager-setup.md`. Current layout is load-bearing but undocumented.

---

## Handoff to Ekko

If Ekko is executing this ship, the secret-side work is purely verification — no creates. Commands to run, in order:

1. The six read-only checks in "Recommended pre-ship command sequence" above.
2. If (1)'s grep for `DS_SHARED_INTERNAL_SECRET` on `demo-factory` SA returns nothing and PR #61's post-merge grep shows `INTERNAL_SECRET` usage in S3: single `gcloud projects add-iam-policy-binding` call to grant `roles/secretmanager.secretAccessor` on that secret to the demo-factory SA, then patch `demo-factory/deploy.sh` to add `INTERNAL_SECRET=DS_SHARED_INTERNAL_SECRET:latest` to `--set-secrets`.
3. If (1) shows `roles/datastore.user` missing on demo-factory SA: single `gcloud projects add-iam-policy-binding` to grant it.
4. If both naming conventions are missing a secret (G7): escalate to Duong — he owns the Secret Manager provisioning authority.

No `age -d`. No `tools/decrypt.sh`. No plaintext secret values in this audit or in command outputs shared to Slack/handoff threads.

---

*End of audit. Heimerdinger (advisor). No secrets were read, decrypted, or modified in producing this document.*
