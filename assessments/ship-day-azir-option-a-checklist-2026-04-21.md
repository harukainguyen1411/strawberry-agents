# Ship-day Deploy Runbook — Azir God Plan v2 (Option A)

**Date:** 2026-04-21 (refresh #3 — direct-to-prod)
**Concern:** work
**Author:** Heimerdinger (advisor — no execution)
**Plan:** `plans/in-progress/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md`
**Related ADRs:**
- `plans/in-progress/work/2026-04-21-s1-new-flow.md` — Viktor's S1 Wave 2 (Phases A-I)
- `plans/proposed/work/2026-04-21-mcp-inprocess-merge.md` — Karma's MCP-in-process ADR (PR #59, merged)
- `plans/proposed/work/2026-04-21-s5-preview-fullview-route.md` — PR #55 (merged)

**Variant:** Option A — MCP-in-process merge on S1
**GCP project / region:** `mmpt-233505` / `europe-west1`
**Executor:** Ekko
**Companion:** `assessments/ship-day-azir-secrets-audit-2026-04-21.md`

---

## Environment reality — single-project direct-to-prod

There is no separate staging project/URL set for Demo Studio. The string "staging" that appears in S1's `FIRESTORE_DATABASE=demo-studio-staging` is the **Firestore database name on the same GCP project**, not an environment partition. All three Cloud Run services (`demo-studio`, `demo-factory`, `demo-preview`) share project `mmpt-233505`, region `europe-west1`, and a single live URL each.

Consequences for this runbook:

1. **No "stg → prod cutover" phase.** One deploy pass per service, one smoke pass, one flag flip window.
2. **Rule 17 ("post-deploy smoke tests run on stg and prod; rollback on prod failure") is relaxed to single-environment smoke.** Rationale: Demo Studio is an internal demo tool with no external users — blast radius is Duong and teammates running live demos, not customers. Rollback automation still applies; the framing just collapses to one environment. Future readers: this is intentional and is documented here so Rule 17 strictness is not over-interpreted on this workload.
3. **Flag `MANAGED_AGENT_MCP_INPROCESS=1` flips in the same deploy pass** (not a staged post-deploy flip). Value set on the deploy command line so the new revision comes up with in-process MCP live from its first request.
4. **Rollback = revision-traffic revert** per service. Path: `gcloud run services update-traffic <svc> --to-revisions=$PREV=100`. The rollback.sh script at `workspace/company-os-ship-day/tools/demo-studio-v3/scripts/rollback.sh` wraps this for S1; S3/S5 are manual (Gap G2).

---

## Target services

| Key | Cloud Run service | Repo path | Role |
|---|---|---|---|
| S1 | `demo-studio` *(deploy.sh line 12; not renamed to `demo-studio-v3`)* | `tools/demo-studio-v3/` | Session shell, chat UI, MCP sub-route, SSE `/logs`, S4-poll |
| S3 | `demo-factory` | `tools/demo-factory/` | `POST /build` + `GET /build/{id}` + S4 auto-trigger |
| S5 | `demo-preview` | `tools/demo-preview/` | `/v1/preview/{id}` iframe + `/v1/preview/{id}/fullview` |
| MCP-legacy | `demo-studio-mcp` (TS) | `tools/demo-studio-mcp/` | Retirement target; traffic → 0 after 48h clean on in-process MCP |

## Current wave state

| Wave | PR | Scope | Status |
|---|---|---|---|
| 1 | #55 | S5 `/v1/preview/{id}/fullview` | Merged |
| 1 | #57 | S3 `POST /build` + S4 auto-trigger | Merged |
| 1 | #59 | S1 MCP in-process (Option A) | Merged |
| 2 | #61 | S1-new-flow phases A-I | **In review — Talon fixing Senna criticals. Blocks ship.** |

Ship blocks until PR #61 merges and lands on `main` of `demo-studio-v3` with CI green.

---

## 0. Blockers / open gaps

| # | Gap | Impact | Owner |
|---|---|---|---|
| G1 | S1 service name = `demo-studio` (per deploy.sh), not `demo-studio-v3`. All `gcloud` commands below use `demo-studio`. | Cosmetic; watch for drift in operator docs. | Ekko confirms. |
| G2 | `scripts/deploy/rollback.sh` does not exist at strawberry-agents repo root. Only rollback.sh in workspace is `workspace/company-os-ship-day/tools/demo-studio-v3/scripts/rollback.sh`, hardcoded to `SERVICE=demo-studio`. | Auto-rollback works for S1 only; S3/S5 rollback is manual. | Ekko (advisory): generalize the script to take `$SERVICE` arg 1 and move to repo root `scripts/deploy/rollback.sh` before ship, or accept manual fallback for S3/S5. |
| G3 | Python MCP-SDK handshake smoke required before `MANAGED_AGENT_MCP_INPROCESS=1` is considered trustworthy (Lucian deploy-gate). Bare HTTP 200 on `/mcp` is insufficient. | If the flag is set in the deploy command without a prior handshake run against a probe URL, a broken in-process MCP surfaces only at first live agent request — potentially during a demo. | Ekko: run the handshake smoke §2.3a BEFORE enabling the flag on the deploy command. |
| G4 | S3 Firestore readiness (Senna I1). Need `google-cloud-firestore` in requirements.txt + `demo-factory` SA has `roles/datastore.user`. | Flag `PROJECTS_FIRESTORE=1` unsafe otherwise. | Verify §1.3. |
| G5 | Legacy MCP consumer scan. If any non-S1 caller still targets `demo-studio-mcp.*run.app`, retirement 404s them. | Unknown external consumers. | Ekko greps before §5. |
| G6 | S3 has zero `INTERNAL_SECRET` / `X-Internal-Secret` references in current HEAD. If PR #61 introduces X-Internal-Secret auth on S3 inbound, S3 needs the secret bound at deploy time. | Potential silent auth failure after PR #61. | Ekko: re-grep `demo-factory/**/*.py` after #61 merge; if any INTERNAL_SECRET appears, patch `demo-factory/deploy.sh` BEFORE deploy. |
| G7 | S3/S5 `deploy.sh` uses lowercase-hyphen secret names (`ds-shared-anthropic-api-key`); S1 uses uppercase-underscore (`DS_SHARED_ANTHROPIC_API_KEY`). These are two distinct Secret Manager objects. | S3/S5 deploy crash if lowercase-hyphen set is absent. | Ekko: `gcloud secrets list` and confirm both naming conventions exist; unify via follow-up PR. |
| G8 | `DEMO_FACTORY_TEST_MODE` must remain UNSET on the demo-factory service. | Setting it activates `_should_fail_build` seam and causes spurious failures. | §1.3 check. |
| G9 | `deploy.sh` scripts do not take `--env`. All three hardcode `mmpt-233505` directly. Consistent with single-project model — no action needed. | None. | Informational. |

---

## 1. Preflight gate

Worktree locations:

- S1: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-studio-v3/`
- S3: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-factory/`
- S5: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-preview/`

### 1.1 PRs merged + CI green

- [ ] **#55** S5 `/v1/preview/{id}/fullview`
- [ ] **#57** S3 `POST /build` + S4 auto-trigger
- [ ] **#59** S1 MCP in-process sub-route
- [ ] **#61** S1-new-flow Wave 2 (Phases A-I) — **blocks ship**
- [ ] Slack-relay PR (drop brand/market/content from `/session/new` body)

Record HEAD SHA per repo.

### 1.2 CI greens

- [ ] S1 CI green on main (unit + xfail + Xayah contract tests)
- [ ] S3 CI green on main
- [ ] S5 CI green on main
- [ ] Caitlyn E2E (8 scenarios, plan §4) green — video in `assessments/qa-reports/`
- [ ] Akali UI regression (Rule 16) green vs Figma — report in `assessments/qa-reports/`

### 1.3 Secrets + IAM provisioning

See companion `assessments/ship-day-azir-secrets-audit-2026-04-21.md` for the full punch list. Spot-checks:

```bash
# (1) DS_STUDIO_MCP_TOKEN exists
gcloud secrets list --project=mmpt-233505 --filter='name~DS_STUDIO_MCP_TOKEN' --format='value(name)'

# (2) demo-runner-sa has secretAccessor on DS_STUDIO_MCP_TOKEN
gcloud secrets get-iam-policy DS_STUDIO_MCP_TOKEN --project=mmpt-233505 \
  --flatten=bindings --filter='bindings.role:roles/secretmanager.secretAccessor' \
  --format='value(bindings.members)' | grep demo-runner-sa || echo "MISSING GRANT"

# (3) S3 SA has Firestore role
gcloud projects get-iam-policy mmpt-233505 --flatten='bindings[].members' \
  --filter='bindings.members~demo-factory AND bindings.role~datastore.user' \
  --format='value(bindings.role)' | grep datastore.user || echo "MISSING FIRESTORE GRANT"

# (4) S3 requirements.txt has google-cloud-firestore
grep -q '^google-cloud-firestore' \
  /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-factory/requirements.txt \
  && echo OK || echo "MISSING google-cloud-firestore"

# (5) DEMO_FACTORY_TEST_MODE NOT set on demo-factory (G8)
gcloud run services describe demo-factory --project=mmpt-233505 --region=europe-west1 \
  --format='value(spec.template.spec.containers[0].env[].name)' \
  | grep -q '^DEMO_FACTORY_TEST_MODE$' && echo "LEAK — UNSET IT" || echo OK

# (6) G6: INTERNAL_SECRET need on S3 after #61 merge
grep -rnE "INTERNAL_SECRET|X-Internal-Secret" \
  /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-factory/ \
  --include="*.py" || echo "OK — S3 does not need INTERNAL_SECRET binding"

# (7) G7: both secret-naming conventions present
gcloud secrets list --project=mmpt-233505 --format='value(name)' \
  | grep -iE 'anthropic|ws.api.key|shared' | sort
```

### 1.4 Secret-leak scan on the shipping diff

```bash
# Per repo
PROD_SHA=$(git -C <repo> rev-parse prod/last-deploy 2>/dev/null || git -C <repo> merge-base HEAD main)
git -C <repo> diff "$PROD_SHA..HEAD" | \
  grep -E "sk-ant-[A-Za-z0-9_-]{20,}|AIzaSy[A-Za-z0-9_-]{33}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----" \
  && echo "LEAK — STOP" || echo CLEAN
git -C <repo> diff "$PROD_SHA..HEAD" | \
  grep -E "(ANTHROPIC_API_KEY|SESSION_SECRET|INTERNAL_SECRET|WS_API_KEY|MCP_TOKEN|FIRECRAWL_API_KEY|DEMO_SERVICE_TOKEN|CONFIG_MGMT_TOKEN|DS_STUDIO_MCP_TOKEN|PREVIEW_TOKEN|FACTORY_TOKEN)\s*=\s*['\"][A-Za-z0-9_-]{16,}" \
  && echo "LEAK — STOP" || echo CLEAN
```

- [ ] CLEAN on S1, S3, S5

### 1.5 Human go/no-go

- [ ] Preflight §1.1–§1.4 green
- [ ] §0 gaps resolved or accepted
- [ ] Window timed to allow ≥60 min post-deploy observation
- [ ] No scheduled demos during the deploy+observation window (internal-tool blast radius still means a broken build ruins a live demo)
- [ ] Sona + Evelynn acknowledge
- [ ] `#demo-studio-alerts` watched

---

## 2. Deploy — single pass, S5 → S3 → S1

Order matters: S5 and S3 are consumed by S1; deploy them first so S1 comes up against fresh dependency revisions. Between each deploy, smoke its block. If any smoke red, STOP and rollback that service before touching the next.

For each service: capture `PREV_REVISION` before; `NEW_REVISION` after.

```bash
SVC=<demo-preview|demo-factory|demo-studio>
PREV_REVISION=$(gcloud run services describe "$SVC" \
  --project=mmpt-233505 --region=europe-west1 \
  --format='value(status.latestReadyRevisionName)')
echo "$SVC pre-deploy: $PREV_REVISION"
```

### 2.1 S5 — `demo-preview`

Additive. New `/v1/preview/{id}/fullview` route alongside existing `/v1/preview/{id}`.

```bash
cd /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-preview
./deploy.sh
```

Smoke §3.1.

### 2.2 S3 — `demo-factory`

Deploy with `PROJECTS_FIRESTORE=1` set on the command line (single-pass model — no separate post-deploy flip). This assumes §1.3 checks (3) and (4) are green; if either red, deploy with the flag OFF and set it in a follow-up update.

```bash
cd /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-factory
./deploy.sh
# Then set the flag on the freshly-deployed revision:
gcloud run services update demo-factory \
  --project=mmpt-233505 --region=europe-west1 \
  --update-env-vars=PROJECTS_FIRESTORE=1
```

Smoke §3.2.

### 2.3 S1 — `demo-studio`

Before deploying, run the MCP-SDK handshake smoke against the **current** `demo-studio` revision's `/mcp` sub-route (PR #59 is already live, so the sub-route exists). This verifies the agent-compatible handshake passes before we enable the flag that routes production agent calls through it.

#### 2.3a MCP-SDK handshake smoke (G3 — before flag enable)

```bash
export S1_MCP="https://<demo-studio-prod-url>/mcp"
export MCP_TOK="$(gcloud secrets versions access latest --secret=DS_STUDIO_MCP_TOKEN --project=mmpt-233505)"
python - <<'PY'
import os, asyncio
from mcp.client.streamable_http import streamablehttp_client
from mcp import ClientSession
async def main():
    async with streamablehttp_client(os.environ["S1_MCP"],
                                     headers={"Authorization": f"Bearer {os.environ['MCP_TOK']}"}) as (r, w, _):
        async with ClientSession(r, w) as s:
            await s.initialize()
            tools = await s.list_tools()
            names = {t.name for t in tools.tools}
            assert len(names) >= 3, f"expected >=3 tools, got {names}"
            # Post-#61: get_last_verification MUST appear.
            assert "get_last_verification" in names, f"missing get_last_verification; got {names}"
            print("HANDSHAKE OK", names)
asyncio.run(main())
PY
unset MCP_TOK
```

**If handshake fails → STOP.** Do not deploy S1 with the flag on. Either disable the flag in the deploy or block ship.

#### 2.3b Deploy with both flags set

```bash
cd /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-studio-v3

# deploy.sh's --set-env-vars line in this repo doesn't carry S5_BASE or
# MANAGED_AGENT_MCP_INPROCESS today. Two options:
#   (A) Patch deploy.sh to append the two new env vars (cleanest; advisory).
#   (B) Run deploy.sh as-is, then set the flags in a follow-up update.
# Option B below to avoid pre-ship deploy.sh edits:

BASE_URL=https://demo-studio.missmp.tech \
MANAGED_AGENT_ID=<id> MANAGED_ENVIRONMENT_ID=<id> MANAGED_VAULT_ID=<id> \
./deploy.sh

gcloud run services update demo-studio \
  --project=mmpt-233505 --region=europe-west1 \
  --update-env-vars=MANAGED_AGENT_MCP_INPROCESS=1,S5_BASE=https://<demo-preview-url>
```

Smoke §3.3.

### 2.4 Deploy gate

- [ ] S5 NEW_REVISION ready, smoke green
- [ ] S3 NEW_REVISION ready, smoke green, flag `PROJECTS_FIRESTORE=1` applied
- [ ] S1 handshake smoke green BEFORE flag enable
- [ ] S1 NEW_REVISION ready, smoke green, flags `MANAGED_AGENT_MCP_INPROCESS=1` + `S5_BASE=...` applied
- [ ] PREV_REVISION recorded per service for rollback

---

## 3. Post-deploy smoke

Rule 17 relaxed to single-environment smoke (see preamble). These checks are mandatory.

### 3.1 S5 smoke

```bash
S5=https://<demo-preview-url>
curl -fsS "$S5/v1/preview/__healthz__" || echo "HEALTH FAIL"
curl -fsS -o /tmp/fullview.html -w "%{http_code}\n" \
  "$S5/v1/preview/<TEST_SESSION_ID>/fullview" | grep -q 200 || echo "FULLVIEW FAIL"
grep -c "<html" /tmp/fullview.html    # >=1
```

- [ ] Healthz 200, fullview 200 non-empty HTML
- [ ] `/v1/preview/{id}` iframe mode still 200 (regression)

### 3.2 S3 smoke

```bash
S3=https://<demo-factory-url>
curl -fsS -X POST "$S3/v1/build" -H 'content-type: application/json' \
  -H "Authorization: Bearer $FACTORY_TOKEN" \
  -d '{"sessionId":"<TEST>"}' || echo "SSE BUILD FAIL"
curl -fsS -X POST "$S3/build" -H 'content-type: application/json' \
  -H "Authorization: Bearer $FACTORY_TOKEN" \
  -d '{"sessionId":"<TEST>"}' | jq -e '.projectId and .buildId' || echo "NEW BUILD FAIL"
curl -fsS "$S3/build/<BUILD_ID>" -H "Authorization: Bearer $FACTORY_TOKEN" \
  | jq -e '.status' || echo "BUILD GET FAIL"

# Firestore write observed
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="demo-factory" AND
   (textPayload:~"firestore" OR textPayload:~"projects_firestore")' \
  --project=mmpt-233505 --limit=20
```

- [ ] `/v1/build` still 200
- [ ] `POST /build` returns `{projectId, buildId}`
- [ ] `GET /build/{id}` returns status
- [ ] Firestore write observed on `POST /build`
- [ ] Same sessionId second call reuses projectId (warm path)

### 3.3 S1 smoke — full Caitlyn suite

Run all 8 scenarios from plan §4. Single back-to-back run. Video recorded.

- [ ] Scenario 1 — Empty-session Slack trigger → session in `configuring`, UI loads, agent greets
- [ ] Scenario 2 — Agent config via MCP → S2 (in-process MCP path active)
- [ ] Scenario 3 — Preview iframe paints from `$S5_BASE/v1/preview/{id}`
- [ ] Scenario 4 — "Open in fullview" opens `$S5_BASE/v1/preview/{id}/fullview`
- [ ] Scenario 5 — Build → S3 → S4 round-trip cold, SSE `/logs` surfaces both `event: build` and `event: verification`
- [ ] Scenario 6 — Verification pass surfaces in UI within 5s of S4 terminal
- [ ] Scenario 7 — Iterate with same projectId (warm)
- [ ] Scenario 8 — Verification fail → iterate → pass loop

Plus SSE endpoint spot-check:

```bash
# With a valid ds_session cookie in $COOKIE
curl -fsS -N -H "Cookie: ds_session=$COOKIE" \
  "https://<demo-studio-url>/session/$SID/logs" | head -20
```

- [ ] Content-type `text/event-stream`
- [ ] `event: build` lines during build
- [ ] `event: verification` terminal within `VERIFICATION_POLL_TIMEOUT_S` (300s default)
- [ ] Unauthenticated request returns 401

### 3.4 Smoke gate

- [ ] All 8 scenarios green back-to-back
- [ ] No 5xx on any service over the 30-min post-flip window
- [ ] v1 ADR regression harness (SE/BD/MAL/MAD) green — Xayah

Any red → rollback per §5.

---

## 4. Post-deploy observation — first 60 min

Logs: Cloud Logging, `resource.labels.service_name` in {`demo-studio`, `demo-factory`, `demo-preview`}.

### 4.1 Error budget

```bash
for SVC in demo-studio demo-factory demo-preview; do
  echo "=== $SVC ==="
  gcloud logging read \
    "resource.type=\"cloud_run_revision\" AND
     resource.labels.service_name=\"$SVC\" AND
     severity>=ERROR AND
     timestamp >= \"$(date -u -v-5M +%Y-%m-%dT%H:%M:%SZ)\"" \
    --project=mmpt-233505 --limit=100 --format='value(textPayload)' | wc -l
done
```

Threshold: >10 errors/5min/service → investigate/rollback.

### 4.2 S3→S4 trigger success rate

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND
   resource.labels.service_name="demo-factory" AND
   (textPayload:~"verify.triggered" OR textPayload:~"verify.failed")' \
  --project=mmpt-233505 --limit=100 --format='value(textPayload)' \
  | awk '/triggered/{t++} /failed/{f++} END{print "triggered="t" failed="f}'
```

Expected: failure rate <5%.

### 4.3 MCP in-process error rate

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND
   resource.labels.service_name="demo-studio" AND
   (textPayload:~"mcp.initialize" OR textPayload:~"mcp.tools_list" OR textPayload:~"mcp.error")' \
  --project=mmpt-233505 --limit=200 --format='value(textPayload)' \
  | awk '/mcp.error/{e++} /mcp.initialize/{i++} END{print "init="i" err="e" rate="(e/(i+0.0001))}'
```

Expected: <1%. Spike → `MANAGED_AGENT_MCP_INPROCESS=0` (hybrid fallback to legacy TS MCP).

### 4.4 SSE `/logs` stream health

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND
   resource.labels.service_name="demo-studio" AND
   (textPayload:~"sse.logs.open" OR textPayload:~"sse.logs.close" OR textPayload:~"sse.logs.error")' \
  --project=mmpt-233505 --limit=200 --format='value(textPayload)'
```

Open/close balanced; persistent errors → investigate.

### 4.5 S4 poller timeout rate

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND
   resource.labels.service_name="demo-studio" AND
   (textPayload:~"verification.timeout" OR textPayload:~"verification.terminal")' \
  --project=mmpt-233505 --limit=200 --format='value(textPayload)' \
  | awk '/timeout/{t++} /terminal/{k++} END{print "terminal="k" timeout="t}'
```

Expected: timeout rate <5% of terminals.

### 4.6 Firestore throughput (S3)

Cloud Monitoring → `firestore.googleapis.com/document/{read,write}_count`. Baseline vs prior day. >3× writes with flat traffic → cache/retry loop.

### 4.7 60-min sign-off

- [ ] Error budget within threshold per service
- [ ] S3→S4 trigger failure <5%
- [ ] MCP in-process error rate <1%
- [ ] SSE `/logs` healthy
- [ ] S4 poller timeout <5%
- [ ] Firestore throughput within 1.5× baseline
- [ ] No user reports in `#demo-studio-alerts`

---

## 5. Rollback

### 5.1 Triggers — immediate rollback

- Any §3.3 smoke scenario fails
- MCP error rate >5% in any 5-min window (post flag enable)
- S3→S4 trigger failure rate >25% sustained
- 5xx rate >5% on any service over any 5-min window
- S4 poller timeout rate >30% (S4 wedged)
- Firestore `permission_denied` stream on S3
- Anthropic 401/403 stream on S1 (secret binding broken)
- Startup crash loop (0 ready pods >2 min)
- Any secret appearing in log lines (rollback + rotate)

### 5.2 Rollback ladder

**Level 1 — flag flip (cheapest, seconds):**

```bash
# MCP fallback to legacy TS MCP
gcloud run services update demo-studio --project=mmpt-233505 --region=europe-west1 \
  --update-env-vars=MANAGED_AGENT_MCP_INPROCESS=0

# Disable new S5 iframe
gcloud run services update demo-studio --project=mmpt-233505 --region=europe-west1 \
  --remove-env-vars=S5_BASE

# Disable Firestore path on S3
gcloud run services update demo-factory --project=mmpt-233505 --region=europe-west1 \
  --update-env-vars=PROJECTS_FIRESTORE=0
```

Flag flips propagate in ~5-10s.

**Level 2 — revision traffic revert:**

S1 (wrapped):
```bash
/Users/duongntd99/Documents/Work/mmp/workspace/company-os-ship-day/tools/demo-studio-v3/scripts/rollback.sh
# Or with specific revision:
ROLLBACK_YES=1 /Users/.../scripts/rollback.sh "$PREV_REVISION_S1"
```

S3/S5 (manual — G2):
```bash
gcloud run services update-traffic demo-factory \
  --project=mmpt-233505 --region=europe-west1 \
  --to-revisions="$PREV_REVISION_S3=100"
gcloud run services update-traffic demo-preview \
  --project=mmpt-233505 --region=europe-west1 \
  --to-revisions="$PREV_REVISION_S5=100"
```

**Level 3 — forward-fix** only for trivial template/static issues affecting no API, ≤15 min patch. Otherwise always rollback first.

### 5.3 Hybrid MCP operation (expected, not rollback)

During 48h burn-in, `demo-studio-mcp` TS service stays at 100% traffic (no change). S1's `MANAGED_AGENT_MCP_INPROCESS=1` routes agent traffic to the in-process MCP. If in-process goes red, flag → 0 restores external TS MCP routing, zero-downtime fallback. This is the reason we keep the TS service deployed during burn-in.

---

## 6. Retirement — `demo-studio-mcp` TS service

**Gate: 48h clean on `MANAGED_AGENT_MCP_INPROCESS=1`** (no MCP rollbacks, no error spikes >1%, no reports).

### 6.1 Consumer scan (G5)

```bash
LEGACY_URL_PATTERN="demo-studio-mcp.*a\.run\.app"
grep -rn -E "$LEGACY_URL_PATTERN" /Users/duongntd99/Documents/Work/mmp/workspace/ \
  --include="*.py" --include="*.ts" --include="*.yaml" --include="*.yml" --include="*.env" \
  | grep -vE "(demo-studio-v3/setup_agent\.py|demo-studio-mcp/)" || echo CLEAN
```

- [ ] No external consumers besides S1 legacy fallback

### 6.2 Drop traffic to 0, observe 7d

```bash
gcloud run services update-traffic demo-studio-mcp \
  --project=mmpt-233505 --region=europe-west1 \
  --to-revisions="$(gcloud run services describe demo-studio-mcp --project=mmpt-233505 --region=europe-west1 --format='value(status.latestReadyRevisionName)')=0"

# Observe 7d:
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="demo-studio-mcp"' \
  --project=mmpt-233505 --limit=10
```

### 6.3 Delete service

```bash
gcloud run services delete demo-studio-mcp --project=mmpt-233505 --region=europe-west1 --quiet
```

### 6.4 Retire dead env vars on S1

`DEMO_STUDIO_MCP_URL` (still read by `setup_agent.py`) becomes dead code. Recommend: leave for 2 weeks rollback safety, then remove via `--remove-env-vars=DEMO_STUDIO_MCP_URL` + delete the fallback branch in `setup_agent.py` via follow-up PR.

---

## 7. Artifacts

- HEAD SHAs per repo (§1.1) → Slack thread
- PREV/NEW revisions per service (§2) → Slack thread
- MCP-SDK handshake smoke output (§2.3a) → Slack thread
- Caitlyn E2E video → `assessments/qa-reports/`
- Akali UI regression → `assessments/qa-reports/`
- 60-min observation summary (§4.7) → `assessments/work/post-deploy-azir-option-a-2026-04-21.md`
- Retirement sign-off (§6) → same file, T+48h
- Secrets audit companion → `assessments/ship-day-azir-secrets-audit-2026-04-21.md`
- Post-mortem if rollback → `learnings/` within 24h

---

## Appendix A — Referenced paths

- Ship plan: `plans/in-progress/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md`
- S1-new-flow ADR: `plans/in-progress/work/2026-04-21-s1-new-flow.md`
- Secrets audit: `assessments/ship-day-azir-secrets-audit-2026-04-21.md`
- S1 worktree: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-studio-v3/`
- S3 worktree: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-factory/`
- S5 worktree: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-preview/`
- MCP-legacy: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-studio-mcp/`
- Rollback helper (S1 only): `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-ship-day/tools/demo-studio-v3/scripts/rollback.sh`

## Appendix B — Flag-ordering rationale

1. `DS_STUDIO_MCP_TOKEN` must pre-exist in Secret Manager before S1 binds at deploy time
2. MCP-SDK handshake smoke before `MANAGED_AGENT_MCP_INPROCESS=1` — in-process MCP must be agent-compatible, not just HTTP-compatible
3. `PROJECTS_FIRESTORE=1` only after S3 requirements + SA IAM verified
4. `S5_BASE` set only after S5 `/fullview` 200 verified
5. `DEMO_FACTORY_TEST_MODE` must NEVER be set

Reverse for rollback: `S5_BASE` removed first (cheapest, most isolated), then `PROJECTS_FIRESTORE=0`, then `MANAGED_AGENT_MCP_INPROCESS=0`. `DS_STUDIO_MCP_TOKEN` never flipped off (token stays provisioned).

## Appendix C — Refresh log

- **2026-04-21 refresh #1** — initial draft for Option A
- **2026-04-21 refresh #2** — Wave 2 PR #61 state; Gap list expanded (G6 INTERNAL_SECRET on S3, G7 S1/S3 secret-name divergence, G8 Wave 2 env surfaces on main, G9 deploy.sh `--env`); SSE end-to-end check; S4 poller timeout metric; service name corrected to `demo-studio`
- **2026-04-21 refresh #3 (this)** — collapsed stg→prod phasing to single-pass direct-to-prod against `mmpt-233505` (no separate staging project exists — `demo-studio-staging` is a Firestore DB name, not an env). Flag `MANAGED_AGENT_MCP_INPROCESS=1` flips in the same deploy. Rule 17 explicitly relaxed to single-environment smoke with blast-radius rationale

---

*End of runbook. Written by Heimerdinger (advisor). Execution belongs to Ekko. No code or infra modified.*
