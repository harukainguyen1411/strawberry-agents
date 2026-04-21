# Ship-day Deploy Checklist — Azir God Plan v2 (Option A)

**Date:** 2026-04-21
**Concern:** work
**Author:** Heimerdinger (advisor — no execution)
**Plan:** `plans/in-progress/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md` (§5 ship gate)
**Variant:** Option A — MCP-in-process merge on S1 (collapse `demo-studio-mcp` TS service into S1 FastAPI sub-route `/mcp`)
**GCP project / region:** `mmpt-233505` / `europe-west1`
**Executor:** Ekko (per advisory-only boundary — Heimerdinger does not deploy)

## Target services

| Key | Cloud Run service | Repo path | Role in v2 flow |
|---|---|---|---|
| S1 | `demo-studio-v3` | `company-os/tools/demo-studio-v3/` | Session shell, chat UI, MCP sub-route, SSE `/logs`, S4-poll |
| S3 | `demo-factory` | `company-os/tools/demo-factory/` | `POST /build` + `GET /build/{id}` + S4 auto-trigger |
| S5 | `demo-preview` | `company-os/tools/demo-preview/` | `/v1/preview/{id}` iframe + `/v1/preview/{id}/fullview` |
| MCP-legacy | `demo-studio-mcp` (TS) | `company-os/tools/demo-studio-mcp/` | **Retirement target** — traffic → 0, delete after 48h |

## TL;DR

- **Preflight:** PRs #55 (S5 fullview — already merged), #57 (S3 `/build` + S4 trigger), #59 (MCP in-process on S1), Viktor Wave 2 S1-new-flow (iframe S5, SSE logs, projectId capture) all merged and green on their branches. CI greens on all four repos. Secrets provisioned (§1.3).
- **Deploy order (stg first, whole chain green before prod):** S5 → S3 → S1. S5 and S3 are additive (new routes, old routes remain). S1 is last because it consumes both and flips the MCP source of truth.
- **Flag flips (strict order, stg then prod, one at a time with a smoke gate between each):** (1) `DS_STUDIO_MCP_TOKEN` in Secret Manager → (2) `MANAGED_AGENT_MCP_INPROCESS=1` on S1 (after Python-SDK handshake smoke) → (3) `PROJECTS_FIRESTORE=1` on S3 (after Firestore creds+lib confirmed) → (4) `S5_BASE` on S1 (after S5 `/fullview` returns 200). `DEMO_FACTORY_TEST_MODE` must remain **UNSET** on prod (Senna I2).
- **Rule 17 gate:** any prod smoke red → `scripts/deploy/rollback.sh` auto-reverts the failing service's Cloud Run revision. Flag rollbacks are Ekko-manual (flip var → redeploy prior revision). Hybrid MCP operation (in-process + legacy TS) is supported during the 48h burn-in.
- **Retirement:** after 48h of clean prod on `MANAGED_AGENT_MCP_INPROCESS=1`, Ekko drops `demo-studio-mcp` traffic to 0 (keep revision, observability window 7d), then `gcloud run services delete demo-studio-mcp`, then retires the now-unused env vars on S1 (legacy MCP URL).

---

## 0. Blockers / open items

| # | Gap | Impact | Decision owner |
|---|---|---|---|
| B1 | `scripts/deploy/rollback.sh` existence on workspace — confirmed created for the prior ship day (Ekko session `99011b4`). Re-verify it covers three services (S1, S3, S5), not just `demo-studio`. If it only handles `demo-studio`, prod smoke rollback on S3/S5 degrades to manual `gcloud run services update-traffic`. | Partial auto-rollback. | Ekko to pre-flight the script before ship. If missing multi-service support, patch before deploy OR accept manual substitute per §6.2. |
| B2 | **Python MCP-SDK handshake smoke on stg is pre-requisite for flag (2).** If Karma's ADR did not include a scripted handshake probe, Ekko must author or run an ad-hoc `python -m mcp.client.stdio_http ...` equivalent against `https://<s1-stg>/mcp` before flipping `MANAGED_AGENT_MCP_INPROCESS=1`. Lucian's deploy-gate finding (#2) is explicit that bare HTTP 200 on `/mcp` is insufficient — the SDK must complete `initialize` + `tools/list`. | Flipping (2) without this check risks prod outage of the whole agent config path. | Heimerdinger recommends Ekko block on handshake-smoke completion. No bypass. |
| B3 | **Senna I1 follow-up**: `google-cloud-firestore` must be in S3's `requirements.txt` and the `demo-factory` service-account must have `roles/datastore.user` (or narrower `datastoreViewer + datastoreImportExportAdmin` per least-privilege) on the target Firestore DB. If either is missing, `PROJECTS_FIRESTORE=1` will 500 on first write. | Flag (3) unsafe to flip. | Ekko verifies in §1.3 pre-deploy checklist. |
| B4 | `demo-studio-mcp` retirement has a **hybrid window risk**: if any external caller (Slack relay, ad-hoc curl, forgotten cron) still targets the legacy TS service URL, dropping traffic to 0 will 404 them. | Unknown external consumers. | Ekko to grep `mmp/workspace` + slack-relay config for the legacy URL before retirement step §7. If found, migrate or extend the hybrid window. |
| B5 | **No E2E smoke replacing the v1 smoke-test.sh for the new v2 surfaces** (SSE `/logs`, iframe `S5_BASE`, projectId round-trip). Caitlyn's Playwright suite (plan §4, 8 scenarios) covers this on stg pre-flip. Prod smoke is narrower: scenarios 1, 3, 5, 6 per plan §5 bullet 5. | Prod smoke coverage is intentional subset — acceptable per plan, but reach/breadth is narrower than unit coverage. | Accept per plan §5; no action. |

---

## 1. Preflight gate

All three service worktrees must be verified. Commands assume worktrees at:

- `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-studio-v3`
- `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-factory`
- `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-preview`

If each repo lives on a separate branch/worktree, Ekko runs §1.1–§1.4 per repo.

### 1.1 PRs merged to their respective `main` branches

- [ ] **#55** — S5 `/v1/preview/{id}/fullview` route (already merged per plan §2.3; confirm commit is on `main` of `demo-preview`)
- [ ] **#57** — S3 `POST /build` + `GET /build/{id}` + S4 auto-trigger (`demo-factory`)
- [ ] **#59** — S1 MCP in-process sub-route (Option A; `demo-studio-v3`)
- [ ] **Viktor Wave 2** — S1-new-flow: iframe S5, SSE `/session/{id}/logs`, projectId capture, S4-poll, session-doc migration, slack-relay empty `initialContext` (`demo-studio-v3`)

```bash
# Per repo:
git -C <repo> fetch origin
git -C <repo> log --oneline origin/main -20
git -C <repo> status --porcelain   # expect clean
```

Record HEAD SHA per repo for audit.

### 1.2 CI greens

Per repo, confirm the latest `main` CI run is green:

```bash
# Example for demo-studio-v3 — adjust remote/repo.
gh run list --repo <org>/demo-studio-v3 --branch main --limit 5 --json status,conclusion,headSha,name
```

- [ ] S1 CI green (unit + contract + xfail tests referenced by plan §test_plan)
- [ ] S3 CI green
- [ ] S5 CI green
- [ ] **Xayah contract tests green** on all three (S3 projectId round-trip, S3→S4 terminal trigger, S5 fullview 200, S1 SSE multiplex, S1 session-doc migration null-defaults)
- [ ] **Caitlyn E2E suite** (8 scenarios from plan §4) green against **staging** within a single back-to-back run — video captured per CLAUDE.md Rule 16, report in `assessments/qa-reports/`
- [ ] **Akali UI regression** green vs Figma, report in `assessments/qa-reports/`

### 1.3 Secrets + IAM provisioning (REQUIRED before flag flips)

Must be complete on BOTH stg and prod before their respective flag flips.

```bash
# (1) DS_STUDIO_MCP_TOKEN — token S1 requires to gate the new in-process /mcp sub-route.
gcloud secrets list --project=mmpt-233505 --filter='name:DS_STUDIO_MCP_TOKEN'
# Expect: DS_STUDIO_MCP_TOKEN exists. If not:
#   Ekko provisions it (value agreed with Karma's ADR) via:
#   gcloud secrets create DS_STUDIO_MCP_TOKEN --project=mmpt-233505 --replication-policy=automatic
#   (followed by `gcloud secrets versions add ... --data-file=...` — NEVER paste on CLI)

# (2) demo-runner-sa has secretAccessor on DS_STUDIO_MCP_TOKEN
gcloud secrets get-iam-policy DS_STUDIO_MCP_TOKEN --project=mmpt-233505 \
  --flatten=bindings \
  --filter='bindings.role:roles/secretmanager.secretAccessor AND bindings.members:serviceAccount:demo-runner-sa*' \
  --format='value(bindings.members)' | grep -q demo-runner-sa || echo "MISSING GRANT"

# (3) S3 service-account has Firestore access (Senna I1)
gcloud projects get-iam-policy mmpt-233505 \
  --flatten='bindings[].members' \
  --filter='bindings.members:serviceAccount:demo-factory* AND bindings.role:roles/datastore.user' \
  --format='value(bindings.role)' | grep -q datastore.user || echo "MISSING FIRESTORE GRANT on demo-factory SA"

# (4) S3 requirements.txt includes google-cloud-firestore
grep -q '^google-cloud-firestore' /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-factory/requirements.txt \
  && echo OK || echo "MISSING google-cloud-firestore in S3 requirements.txt"

# (5) DEMO_FACTORY_TEST_MODE must NOT be set on prod S3 (Senna I2)
gcloud run services describe demo-factory --project=mmpt-233505 --region=europe-west1 \
  --format='value(spec.template.spec.containers[0].env[].name)' | grep -q '^DEMO_FACTORY_TEST_MODE$' \
  && echo "LEAK: DEMO_FACTORY_TEST_MODE is set on prod — MUST BE UNSET" || echo OK
```

- [ ] (1)+(2) token + IAM grant present on stg AND prod
- [ ] (3)+(4) Firestore stack ready on S3
- [ ] (5) `DEMO_FACTORY_TEST_MODE` absent on prod

### 1.4 Secret scan on prod→HEAD diff per repo

```bash
# Per repo, against last-deployed SHA (or main merge-base if unknown):
PROD_SHA=$(git -C <repo> rev-parse prod/last-deploy 2>/dev/null || git -C <repo> merge-base HEAD main)
git -C <repo> diff "$PROD_SHA..HEAD" | \
  grep -E "sk-ant-[A-Za-z0-9_-]{20,}|AIzaSy[A-Za-z0-9_-]{33}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----" \
  && echo "POTENTIAL SECRET LEAK — STOP" || echo CLEAN
git -C <repo> diff "$PROD_SHA..HEAD" | \
  grep -E "(ANTHROPIC_API_KEY|SESSION_SECRET|INTERNAL_SECRET|WS_API_KEY|MCP_TOKEN|FIRECRAWL_API_KEY|DEMO_SERVICE_TOKEN|CONFIG_MGMT_TOKEN|DS_STUDIO_MCP_TOKEN)\s*=\s*['\"][A-Za-z0-9_-]{16,}" \
  && echo "POTENTIAL SECRET LEAK — STOP" || echo CLEAN
```

- [ ] CLEAN on S1, S3, S5

### 1.5 Preflight gate summary — all must be GREEN

- [ ] §1.1 all four PRs merged, HEAD SHAs recorded per repo
- [ ] §1.2 CI green on all three services; Caitlyn E2E + Akali UI reports attached
- [ ] §1.3 secrets + IAM provisioned on stg AND prod; `DEMO_FACTORY_TEST_MODE` unset on prod
- [ ] §1.4 secret scan clean on all three repos

---

## 2. Staging deploy (per service, in order)

Order: **S5 → S3 → S1.** Between each service deploy, run its own smoke; do not chain deploys if any service is red.

For each deploy, capture `PREV_REVISION` and `NEW_REVISION` for rollback.

```bash
# Generic snippet — repeat per service with $SVC in {demo-preview, demo-factory, demo-studio-v3}
SVC=<service>
PREV_REVISION=$(gcloud run services describe "$SVC" \
  --project=mmpt-233505 --region=europe-west1 \
  --format='value(status.latestReadyRevisionName)')
echo "$SVC pre-deploy (stg): $PREV_REVISION"
```

### 2.1 S5 — `demo-preview` (stg)

Additive: new `/v1/preview/{id}/fullview` route. Existing `/v1/preview/{id}` remains.

```bash
cd /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-preview
./deploy.sh --env=stg    # or whatever the repo's convention is; Ekko confirms
```

Stg smoke (§3.1 S5 block). **Do NOT flip `S5_BASE` on S1 yet.**

### 2.2 S3 — `demo-factory` (stg)

Additive: new `POST /build` + `GET /build/{id}`. Old SSE `/v1/build` remains. S3→S4 trigger is code-level and fires automatically on terminal build state.

**Leave `PROJECTS_FIRESTORE` UNSET on this first deploy** — the flag flip happens after S3 smoke confirms the existing non-Firestore path still works post-deploy.

```bash
cd /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-factory
./deploy.sh --env=stg
```

Stg smoke (§3.2 S3 block) with flag OFF.

### 2.3 S1 — `demo-studio-v3` (stg)

Deploy with flags:
- `MANAGED_AGENT_MCP_INPROCESS=0` (still using legacy TS MCP via external URL)
- `S5_BASE` UNSET (still using whatever the prior iframe target was)

This is a "code lands dark" deploy. The new code paths are present but behavior matches prior revision.

```bash
cd /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-studio-v3
./deploy.sh --env=stg
```

Stg smoke (§3.3 S1 block) with both flags OFF.

### 2.4 Stg deploy gate

- [ ] S5 `NEW_REVISION` ready, smoke green
- [ ] S3 `NEW_REVISION` ready, smoke green (flag OFF)
- [ ] S1 `NEW_REVISION` ready, smoke green (both flags OFF)
- [ ] All `PREV_REVISION` values recorded

---

## 3. Staging smoke (per service) + flag-flip gates

### 3.1 S5 stg smoke

```bash
S5_STG=https://<demo-preview-stg-url>
curl -fsS "$S5_STG/v1/preview/__healthz__" || echo "HEALTH FAIL"
# Known-good sessionId required; Ekko provisions a throwaway test session.
curl -fsS -o /tmp/fullview.html -w "%{http_code}\n" \
  "$S5_STG/v1/preview/<TEST_SESSION_ID>/fullview" | grep -q 200 || echo "FULLVIEW FAIL"
grep -c "<html" /tmp/fullview.html   # expect >=1
```

- [ ] Healthz 200, fullview 200 with non-empty HTML, no S1 chrome markers
- [ ] `/v1/preview/{id}` (iframe mode) still 200 (regression)

### 3.2 S3 stg smoke (flag OFF)

```bash
S3_STG=https://<demo-factory-stg-url>
# Existing path intact
curl -fsS -X POST "$S3_STG/v1/build" -H 'content-type: application/json' -d '{"sessionId":"<TEST>"}' || echo "SSE BUILD FAIL"
# New path 200 with projectId echo
curl -fsS -X POST "$S3_STG/build" -H 'content-type: application/json' \
  -d '{"sessionId":"<TEST>"}' | jq -e '.projectId and .buildId' || echo "NEW BUILD FAIL"
# GET /build/{id}
curl -fsS "$S3_STG/build/<BUILD_ID>" | jq -e '.status' || echo "BUILD GET FAIL"
```

- [ ] `/v1/build` still works
- [ ] `POST /build` returns `{projectId, buildId}`
- [ ] `GET /build/{id}` returns status
- [ ] Logs show S3 auto-POSTed to S4 `/verify` on build terminal state (check S4 access logs)

#### 3.2a Flip `PROJECTS_FIRESTORE=1` on S3 stg

```bash
gcloud run services update demo-factory \
  --project=mmpt-233505 --region=europe-west1 \
  --update-env-vars=PROJECTS_FIRESTORE=1
```

Re-run §3.2 smoke. Verify S3 logs show Firestore write on `POST /build`:

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="demo-factory" AND
   (textPayload:~"firestore" OR textPayload:~"projects_firestore")' \
  --project=mmpt-233505 --limit=20
```

- [ ] Firestore write observed; no exception
- [ ] Second build with same sessionId reuses projectId (warm path, plan §4 scenario 7)

### 3.3 S1 stg smoke (both flags OFF)

Run Caitlyn's Playwright suite (8 scenarios, plan §4). Video recorded.

- [ ] Scenarios 1–8 all green

#### 3.3a Flip `MANAGED_AGENT_MCP_INPROCESS=1` on S1 stg — **preceded by SDK handshake smoke (B2)**

```bash
# STEP 1: Python MCP-SDK handshake against S1's own /mcp sub-route.
# Ekko runs from a workstation with network access to the stg URL.
# This smoke MUST complete initialize + tools/list before proceeding.
python - <<'PY'
import httpx, json, os
url = os.environ["S1_STG_MCP"]  # e.g. https://<s1-stg>/mcp
tok = os.environ["MCP_TOK"]      # short-lived; from DS_STUDIO_MCP_TOKEN stg
# Pseudocode — replace with the Python MCP SDK client handshake per Karma's ADR.
# Must assert: protocol initialize returns capability list; tools/list returns >=3 tools.
PY
```

If handshake fails → **DO NOT FLIP.** Investigate.

```bash
# STEP 2: flip the flag.
gcloud run services update demo-studio-v3 \
  --project=mmpt-233505 --region=europe-west1 \
  --update-env-vars=MANAGED_AGENT_MCP_INPROCESS=1
```

Re-run plan §4 scenario 2 (agent config via MCP → S2). Verify S2 received write within 2s.

- [ ] MCP handshake probe green
- [ ] `set_config` via in-process MCP round-trips to S2
- [ ] Anthropic managed agent tool call succeeds end-to-end

#### 3.3b Flip `S5_BASE` on S1 stg

```bash
gcloud run services update demo-studio-v3 \
  --project=mmpt-233505 --region=europe-west1 \
  --update-env-vars=S5_BASE=https://<demo-preview-stg-url>
```

Re-run plan §4 scenarios 3, 4 (iframe + fullview from S5).

- [ ] Iframe src resolves to `$S5_BASE/v1/preview/{id}` and paints
- [ ] "Open in fullview" opens new tab to `$S5_BASE/v1/preview/{id}/fullview`

### 3.4 Stg integrated smoke gate

- [ ] All 8 plan §4 scenarios green back-to-back with flags (2),(3),(4) ON
- [ ] No 5xx on any of the three services over the 30-min post-flip window
- [ ] v1 ADRs (SE/BD/MAL/MAD) remain green — run Xayah's regression harness

**STOP** if any step above is red. Rollback the failing service's flag first (flag flip is cheaper than revision rollback), then, if still red, revert the Cloud Run revision.

---

## 4. Prod deploy + smoke

**Human go/no-go gate.**

- [ ] Sona + Evelynn acknowledge stg green for ≥30 min (ideally ≥2h soak)
- [ ] §0 blockers accepted or mitigated (B1 rollback script multi-service OK, B2 handshake smoke run on stg, B3 Firestore grants on prod verified, B4 legacy MCP consumer grep clean)
- [ ] Window timed to allow ≥60 min post-deploy observation
- [ ] On-call aware; `#demo-studio-alerts` watched

### 4.1 Prod deploy — same order S5 → S3 → S1, all flags OFF on first deploy

For each service, capture PREV_REVISION, run `./deploy.sh --env=prod` (or the repo's prod flag), capture NEW_REVISION. Write both to the Slack thread.

- [ ] S5 prod deployed, smoke §4.2 S5 block green
- [ ] S3 prod deployed, smoke §4.2 S3 block green (flag OFF)
- [ ] S1 prod deployed, smoke §4.2 S1 block green (both flags OFF)

Rule 17: **on any prod smoke failure, `scripts/deploy/rollback.sh <service>` auto-reverts the failing service.** Do not proceed.

### 4.2 Prod smoke — narrow subset per plan §5 bullet 5

Scenarios 1, 3, 5, 6 from plan §4:

1. **Empty-session Slack trigger** — Slack slash-command → S1 creates session w/ empty `initialContext`; UI loads; agent greets.
3. **Preview iframe from S5** — after one config write, iframe paints (status 200, non-empty DOM).
5. **Build → S3 → S4 round-trip (cold)** — fresh `projectId`, persisted, S3 auto-POSTs S4, SSE `/logs` surfaces both.
6. **Verification pass surfaces in UI** — `verificationStatus = passed` via SSE within 5s of S4 terminal.

Run within 15 min of prod code deploy (plan §5).

### 4.3 Prod flag flips — same strict order, with smoke between

Each flip triggers a manual re-run of its narrow smoke (listed below). Any red → flag-rollback (flip OFF) first, then revision-rollback if still red.

1. **(1) Confirm `DS_STUDIO_MCP_TOKEN` provisioned on prod** — already checked §1.3. No flip needed; token must exist prior to S1 prod deploy.
2. **(2) `MANAGED_AGENT_MCP_INPROCESS=1` on S1 prod**
   - Pre: run MCP-SDK handshake smoke against prod `/mcp` (B2).
   - Flip via `gcloud run services update demo-studio-v3 ...`.
   - Smoke: scenario 2 (agent `set_config` → S2) once, via a throwaway prod session.
   - Rollback: `--update-env-vars=MANAGED_AGENT_MCP_INPROCESS=0`; S1's `setup_agent` reverts to external `demo-studio-mcp` TS URL (hybrid mode).
3. **(3) `PROJECTS_FIRESTORE=1` on S3 prod**
   - Pre: §1.3 confirmed `google-cloud-firestore` in requirements + SA IAM grant.
   - Flip via `gcloud run services update demo-factory ...`.
   - Smoke: scenario 5 + 7 (cold build + warm build, projectId reuse verified).
   - Rollback: `--update-env-vars=PROJECTS_FIRESTORE=0`; S3 reverts to prior (non-Firestore) projectId storage.
4. **(4) `S5_BASE=<demo-preview prod URL>` on S1 prod**
   - Flip via `gcloud run services update demo-studio-v3 ...`.
   - Smoke: scenarios 3 + 4 (iframe + fullview).
   - Rollback: `--remove-env-vars=S5_BASE` or revert to prior value.

### 4.4 Prod smoke + flag gate

- [ ] Scenarios 1, 3, 5, 6 all green in a single 15-min window post-code-deploy (flags OFF)
- [ ] After each flag flip, its targeted scenario re-run and green
- [ ] `#demo-studio-alerts` clean during each 5-min gate window

---

## 5. Post-deploy observation — first 60 min

Watch per-service. Logs in Cloud Logging with `resource.labels.service_name` in {`demo-studio-v3`, `demo-factory`, `demo-preview`}.

### 5.1 Error budget (all three services)

```bash
for SVC in demo-studio-v3 demo-factory demo-preview; do
  echo "=== $SVC ==="
  gcloud logging read \
    "resource.type=\"cloud_run_revision\" AND
     resource.labels.service_name=\"$SVC\" AND
     severity>=ERROR AND
     timestamp >= \"$(date -u -v-5M +%Y-%m-%dT%H:%M:%SZ)\"" \
    --project=mmpt-233505 --limit=100 --format='value(textPayload)' | wc -l
done
```

**Threshold:** >10 errors in any 5-min window per service → investigate / consider rollback.

### 5.2 S3→S4 trigger success rate

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND
   resource.labels.service_name="demo-factory" AND
   (textPayload:~"verify.triggered" OR textPayload:~"verify.failed")' \
  --project=mmpt-233505 --limit=100 --format='value(textPayload)' \
  | awk '/triggered/{t++} /failed/{f++} END{print "triggered="t" failed="f}'
```

**Expected:** failure rate <5%. Higher indicates S4 connectivity issue.

### 5.3 MCP in-process handshake success rate (S1)

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND
   resource.labels.service_name="demo-studio-v3" AND
   (textPayload:~"mcp.initialize" OR textPayload:~"mcp.tools_list" OR textPayload:~"mcp.error")' \
  --project=mmpt-233505 --limit=200 --format='value(textPayload)' \
  | awk '/mcp.error/{e++} /mcp.initialize/{i++} END{print "init="i" errors="e" err_rate="(e/(i+0.0001))}'
```

**Expected:** error rate <1%. Any `mcp.error` stream → rollback flag (2) to OFF (hybrid mode) immediately.

### 5.4 SSE `/logs` stream health (S1)

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND
   resource.labels.service_name="demo-studio-v3" AND
   (textPayload:~"sse.logs.open" OR textPayload:~"sse.logs.close" OR textPayload:~"sse.logs.error")' \
  --project=mmpt-233505 --limit=200 --format='value(textPayload)'
```

**Expected:** open/close balanced; errors isolated. Persistent `sse.logs.error` → investigate.

### 5.5 Firestore throughput (S3, post-flag-3)

Cloud Monitoring → Firestore metrics (`firestore.googleapis.com/document/{read,write}_count`) for the S3 project DB. Baseline vs prior day same window. >3× write rate with flat traffic → cache/retry loop.

### 5.6 60-min sign-off

- [ ] Error rate within budget (§5.1) per service
- [ ] S3→S4 trigger failure rate <5% (§5.2)
- [ ] MCP in-process error rate <1% (§5.3)
- [ ] SSE `/logs` stream healthy (§5.4)
- [ ] Firestore throughput within 1.5× baseline (§5.5)
- [ ] No user reports in `#demo-studio-alerts`

---

## 6. Rollback decision tree

### 6.1 Triggers — IMMEDIATE rollback

- Prod smoke scenarios 1, 3, 5, or 6 fails (Rule 17)
- MCP error rate spike (>5% in any 5-min window after flag (2) ON)
- S3→S4 trigger failure rate >25% sustained
- 5xx rate >5% on any service over any 5-min window
- Firestore `permission_denied` stream on S3
- Anthropic 401/403 stream on S1 (secret binding broken)
- Startup crash loop on any service (0 ready pods >2 min)
- Any secret appearing in log lines (rollback + rotate)

### 6.2 Rollback ladder — try cheaper rollbacks first

**Level 1 — flag flip (cheapest, no deploy):**

```bash
# Flag (4) S5_BASE: revert S1 to prior iframe target
gcloud run services update demo-studio-v3 --project=mmpt-233505 --region=europe-west1 \
  --remove-env-vars=S5_BASE
# Flag (3) PROJECTS_FIRESTORE: revert S3 to non-Firestore path
gcloud run services update demo-factory --project=mmpt-233505 --region=europe-west1 \
  --update-env-vars=PROJECTS_FIRESTORE=0
# Flag (2) MANAGED_AGENT_MCP_INPROCESS: revert S1 to external TS MCP URL (hybrid mode)
gcloud run services update demo-studio-v3 --project=mmpt-233505 --region=europe-west1 \
  --update-env-vars=MANAGED_AGENT_MCP_INPROCESS=0
```

Flag flips take effect on the next request boundary (~5–10s for Cloud Run env-var propagation).

**Level 2 — Cloud Run revision rollback (auto via `scripts/deploy/rollback.sh <service>`):**

```bash
# If rollback.sh exists and supports the service name (B1):
scripts/deploy/rollback.sh demo-studio-v3   # or demo-factory / demo-preview

# Manual fallback:
gcloud run services update-traffic <SVC> \
  --project=mmpt-233505 --region=europe-west1 \
  --to-revisions="$PREV_REVISION=100"
```

**Level 3 — forward-fix only if** root cause is a trivial template/static-asset issue affecting no API, AND ≤15 min to patch. Otherwise always rollback first, fix later.

### 6.3 Hybrid MCP operation (expected, not rollback)

During the 48h burn-in, `demo-studio-mcp` TS service is **kept alive at 100% traffic** (no change) while S1's `MANAGED_AGENT_MCP_INPROCESS=1` routes agent traffic to in-process MCP. If in-process MCP goes red, flag (2) → 0 makes S1 setup_agent point back at the TS service URL — zero-downtime fallback. This hybrid is the reason Karma's ADR retains the TS repo.

---

## 7. Retirement — `demo-studio-mcp` TS service

**Gate: 48h of clean prod with `MANAGED_AGENT_MCP_INPROCESS=1`** (no MCP-related rollbacks, no error spikes >1%, no user reports).

### 7.1 Consumer scan (B4)

```bash
# In workspace repo: any non-S1 consumer of the legacy TS URL?
LEGACY_URL_PATTERN="demo-studio-mcp.*a\.run\.app"
grep -rn -E "$LEGACY_URL_PATTERN" /Users/duongntd99/Documents/Work/mmp/workspace/ \
  --include="*.py" --include="*.ts" --include="*.yaml" --include="*.yml" --include="*.env" \
  | grep -v -E "(demo-studio-v3/setup_agent\.py|demo-studio-mcp/)" || echo CLEAN
```

- [ ] No external consumers besides S1's legacy fallback path

### 7.2 Drop traffic to 0 (keep revision for 7d observability)

```bash
# Route 0% traffic to demo-studio-mcp latest revision; service remains deployed.
gcloud run services update-traffic demo-studio-mcp \
  --project=mmpt-233505 --region=europe-west1 \
  --to-revisions="$(gcloud run services describe demo-studio-mcp --project=mmpt-233505 --region=europe-west1 --format='value(status.latestReadyRevisionName)')=0"

# Observe for 7 days: any request during this window is a sign of a missed consumer.
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="demo-studio-mcp"' \
  --project=mmpt-233505 --limit=10
```

**If any request lands during the 7d observation window, halt retirement and investigate.**

### 7.3 Delete service

```bash
gcloud run services delete demo-studio-mcp \
  --project=mmpt-233505 --region=europe-west1 \
  --quiet
```

### 7.4 Retire now-unused env vars on S1

The legacy MCP URL env var (e.g. `DEMO_STUDIO_MCP_URL` or whatever `setup_agent.py` reads when `MANAGED_AGENT_MCP_INPROCESS=0`) is now dead code. Two options:

- **Option A — leave in place** for one more release cycle (rollback safety). Recommended.
- **Option B — remove** via `--remove-env-vars=DEMO_STUDIO_MCP_URL` and delete the fallback branch in `setup_agent.py` in a follow-up PR.

Heimerdinger recommends **Option A** for 2 weeks post-delete, then Option B via a planned commit by Viktor.

### 7.5 Retirement sign-off

- [ ] 7d observation window on 0%-traffic revision: zero requests
- [ ] `gcloud run services delete demo-studio-mcp` successful
- [ ] C3 tracker (`strawberry-agents` commit `fe452d4`) updated / closed
- [ ] Karma's ADR updated to note retirement complete

---

## 8. Artifacts

- Pre-deploy HEAD SHAs per repo (§1.1) → Slack thread
- PREV/NEW revisions for stg and prod per service (§2, §4) → Slack thread
- MCP-SDK handshake smoke output (§3.3a, §4.3.2) → Slack thread
- Caitlyn E2E video (plan §4 scenarios) → `assessments/qa-reports/`
- Akali UI regression report → `assessments/qa-reports/`
- 60-min prod observation summary (§5.6) → `assessments/work/post-deploy-azir-option-a-2026-04-21.md` (Heimerdinger or on-call writes)
- Retirement sign-off (§7.5) → same post-deploy file, appended at T+48h
- If rollback: post-mortem in `learnings/` within 24h

---

## Appendix A — Referenced paths

- Ship plan (v2): `/Users/duongntd99/Documents/Personal/strawberry-agents/plans/in-progress/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md`
- Prior ship checklist (template): `/Users/duongntd99/Documents/Personal/strawberry-agents/assessments/ship-day-deploy-checklist-2026-04-21.md`
- S1 worktree: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-studio-v3/`
- S3 worktree: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-factory/`
- S5 worktree: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-preview/`
- MCP-legacy worktree (retirement target): `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-studio-mcp/`
- Rollback script (verify multi-service support): `scripts/deploy/rollback.sh`

## Appendix B — Flag-flip ordering rationale (why strict)

1. `DS_STUDIO_MCP_TOKEN` first → token must exist in Secret Manager before S1 deploy binds it, else startup crash loop.
2. `MANAGED_AGENT_MCP_INPROCESS=1` second, only after SDK handshake smoke → guarantees the in-process MCP path is agent-compatible, not just HTTP-compatible (Lucian #2).
3. `PROJECTS_FIRESTORE=1` third, only after S3 deploy stabilized → Firestore path is additive to S3 only; flipping prematurely before deploy stabilization conflates failure domains.
4. `S5_BASE` last → S1 iframe target change is user-visible; flipping after (1)–(3) means any user-visible red is known to be S5-related, not MCP/Firestore.
5. `DEMO_FACTORY_TEST_MODE` must never be set on prod (Senna I2) → `_should_fail_build` seam becomes active and causes spurious failures.

Reverse order applies for rollback: flip (4) OFF first (cheapest, most isolated), then (3), then (2). (1) is never flipped OFF — token stays provisioned.

---

*End of checklist. Written by Heimerdinger (advisor). Execution belongs to Ekko. No code or infra was modified in producing this document.*
