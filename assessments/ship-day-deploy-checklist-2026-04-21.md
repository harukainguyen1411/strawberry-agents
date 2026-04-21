# Ship-day Deploy Checklist — MAD/MAL/BD/SE (Heimerdinger)

**Date:** 2026-04-21
**Concern:** work
**Author:** Heimerdinger (advisor — no execution)
**Target service:** `demo-studio` on Cloud Run (`mmpt-233505` / `europe-west1`)
**Source branch:** `company-os-integration` (worktree at `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration`, branch `integration/demo-studio-v3-waves-1-4`, HEAD `8a397e6` at checklist authoring)
**Ship ADR:** `plans/implemented/work/2026-04-21-demo-studio-v3-e2e-ship.md`

## TL;DR

- **Preflight:** full pytest green on `company-os-integration` (exclude `test_integration_l3.py` by marker — it is a known xfail L3 harness), claim-contract grep clean, secret-scan the prod→HEAD diff, confirm working tree clean.
- **Staging:** `BASE_URL=<stg>` + required envs → run `tools/demo-studio-v3/deploy.sh` (single Cloud Run deploy) → `scripts/smoke-test.sh <stg-url>` → all 8 smoke checks pass before touching prod.
- **Prod:** same deploy script with prod `BASE_URL` → `scripts/smoke-test.sh <prod-url>` → if red, **MANUAL** traffic rollback via `gcloud run services update-traffic demo-studio --to-revisions=<previous>=100` (see Blockers §0 — no `rollback.sh` exists).

---

## 0. Blockers

These gaps must be acknowledged before ship. None are individually blocking if Sona accepts the manual substitute noted.

| # | Gap | Impact | Manual substitute |
|---|---|---|---|
| B1 | **`scripts/deploy/rollback.sh` does not exist** in the workspace nor in `strawberry-agents/scripts/deploy/`. The E2E ship ADR §8.2 and CLAUDE.md Rule 17 both reference it as the auto-trigger on prod smoke failure. | No auto-rollback on prod smoke failure. | Operator must run `gcloud run services update-traffic demo-studio --to-revisions=<PREVIOUS_REVISION>=100 --region=europe-west1 --project=mmpt-233505`. See §6.2 for the exact recipe. |
| B2 | **No `.github/workflows/` on `company-os-integration`** — the `e2e.yml` / `tdd-gate.yml` referenced in CLAUDE.md Rules 12/15 are not installed in this repo. Tests are gated locally only. | No CI enforcement of TDD / E2E gates for this ship. | Evelynn / Sona must manually verify the gate-list in §1 below before approving the deploy. |
| B3 | **No `tests/smoke/test_e2e_ship.py`** — the ship-ADR §5 calls for a 10-scenario standalone smoke script; only `scripts/smoke-test.sh` (8 HTTP probes) exists. | MAD tab, terminate action, S2 enrichment, orphan path are **not smoke-covered**. | Operator must perform the post-deploy manual MAD-tab verification in §3.2 below. A follow-up ADR task to author the full `test_e2e_ship.py` should be filed. |
| B4 | **Cloud Run instance pinning not set** in `deploy.sh` (no `--min-instances` / `--max-instances`). Ship ADR OQ-SHIP-1 flagged this; resolution was "pin to min=max=1", but `deploy.sh` HEAD still does not contain the flag. | On any auto-scale to >1 instance, MAL scanner dedup cache + MAD list TTL cache silently mis-behave (duplicate slack warnings, stale cache views). | Either patch `deploy.sh` before running ship-day (add `--min-instances=1 --max-instances=1`) or accept the known degradation and set `MANAGED_SESSION_MONITOR_ENABLED=false` until pinned. |
| B5 | **W10 env-vars not in `deploy.sh` HEAD.** Ship ADR §6.3 requires `IDLE_WARN_MINUTES`, `IDLE_TERMINATE_MINUTES`, `SCAN_INTERVAL_SECONDS`, `SLACK_ALERT_CHANNEL`, `MANAGED_SESSION_MONITOR_ENABLED`, `MANAGED_AGENT_DASHBOARD`. Current `deploy.sh` `--set-env-vars` contains 12 entries, none of these. | The MAL scanner + MAD dashboard ship dark (flag-off by missing env). Acceptable for the initial ship per ADR §4.3 (W10 is a separate flag-flip PR) but means **this deploy does NOT light up MAD/MAL** — only SE/BD/base land functionally. | Confirm with Sona whether ship-day intent is "land code dark" or "land + flip". If latter, patch `deploy.sh` `--set-env-vars` list before deploy. |

**Recommended action before ship:** Sona confirms B1 (manual rollback OK), B3 (manual MAD verify OK), B4+B5 (either patch deploy.sh or accept dark-land). B2 is informational.

---

## 1. Preflight gate

All steps run from the integration worktree. Commands are paste-ready.

### 1.1 Working-tree and branch state

```bash
cd /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration

# Must be on the integration branch, clean tree.
git status --porcelain           # expect: empty
git rev-parse --abbrev-ref HEAD  # expect: integration/demo-studio-v3-waves-1-4
git rev-parse HEAD               # record SHA for audit trail
git log --oneline -10            # expect: MAD.B, MAD.C, MAL.B, SE, BD commits visible
```

Record the HEAD SHA. At checklist authoring it was `8a397e6`. Viktor's in-flight MAD.B/C/F work must land before ship; re-verify.

### 1.2 Branch-protection expectation

This deploy does **NOT** go through a GitHub PR. The `company-os-integration` worktree is a local integration branch on the workspace repo; it has no `.github/workflows/` and no branch-protection rules apply (see Blocker B2). Deploys run from the local worktree directly against Cloud Run. CLAUDE.md Rule 18 (no `--admin` merges) does not apply because no merge is performed. Audit trail is the `git log` output recorded in §1.1 plus the `gcloud run revisions list` output post-deploy.

### 1.3 Full pytest green

```bash
cd /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-studio-v3

# Pre-req: validate local env.
./scripts/validate-env.sh

# Full unit/integration suite — exclude the L3 harness (known xfail design-spec per
# file docstring: RED until Jayce+Viktor finish L1 SSE contract work; unrelated to
# MAD/MAL/BD/SE and not on the ship-critical path).
pytest -x --ignore=tests/test_integration_l3.py

# Expected: 0 failed, all MAD/MAL/BD/SE suites green. Specifically verify:
pytest tests/test_session_store_crud.py tests/test_session_store_mutations.py \
       tests/test_session_store_list.py tests/test_session_store_events.py \
       tests/test_session_store_no_config_write.py \
       tests/test_transition_status_terminal_hook.py \
       tests/test_stop_managed_session.py \
       tests/test_managed_sessions_list.py tests/test_managed_sessions_terminate.py \
       tests/test_managed_sessions_cache.py tests/test_managed_sessions_cache_invalidate_on_terminate.py \
       tests/test_managed_sessions_errors.py tests/test_managed_sessions_routes.py \
       tests/test_managed_agents_tab.py \
       tests/test_sessions_tab_regression.py \
       tests/test_factory_bridge_no_translation.py \
       tests/test_config_client_and_sample_deleted.py \
       tests/test_main_session_create_no_config.py \
       tests/test_no_local_validation.py \
       tests/test_approve_route_gone.py \
       -v
```

**Exclusion reason for `test_integration_l3.py`:** file docstring declares "tests are RED until Jayce + Viktor implement [L1 SSE contract items]". This is a separate L3 design-spec harness for SSE reconnect / message_id dedup — not a MAD/MAL/BD/SE surface. If Viktor's MAD.F work touches L1 SSE contract, re-evaluate.

### 1.4 Claim-contract import sanity

No code under `tools/demo-studio-v3/` should import from a `tools.demo-studio-v3.*` prefix (Orianna claim-contract rule — see `plans/implemented/work/2026-04-21-orianna-claim-contract-work-repo-prefixes.md`).

```bash
cd /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-studio-v3

# Must return zero matches in Python source.
grep -rn "from tools\.demo-studio-v3\|import tools\.demo-studio-v3" \
  --include="*.py" --exclude-dir=__pycache__ . || echo "CLEAN"
```

Also verify the grep-gate allowlist is unchanged vs. base (the MAD allowlist row from ship ADR §2.1 point 5 should be present):

```bash
git diff main -- grep-gate-allowlist.yml   # review any diff
```

### 1.5 Secret scan on the prod→HEAD diff

The current prod revision is recorded in `docs/cloud-run-config-snapshot.md` as `demo-studio-00025-dlz` (image digest `sha256:3d346b1c…`). The image digest is not a git SHA; the prod-deploy SHA must be recovered from the Cloud Run revision labels or the last successful deploy commit. Use either:

```bash
# Option A — if the last-deploy SHA is tagged locally (ops convention):
PROD_SHA=$(git rev-parse prod/last-deploy 2>/dev/null || true)

# Option B — ask Sona / Evelynn for the SHA from the prior deploy run. If
# no prior prod deploy of the v3 surface exists, use the main branch tip:
PROD_SHA=$(git merge-base HEAD main)

echo "Prod baseline SHA: $PROD_SHA"
echo "Ship HEAD SHA: $(git rev-parse HEAD)"

# Diff the range. Scan for secret patterns.
git diff "$PROD_SHA..HEAD" -- tools/demo-studio-v3/ | \
  grep -E "(ANTHROPIC_API_KEY|SESSION_SECRET|INTERNAL_SECRET|WS_API_KEY|MCP_TOKEN|FIRECRAWL_API_KEY|DEMO_SERVICE_TOKEN|CONFIG_MGMT_TOKEN)\s*=\s*['\"][A-Za-z0-9_-]{16,}" \
  && echo "POTENTIAL SECRET LEAK — STOP" || echo "CLEAN"

# Also scan for the generic patterns the pre-commit hook would catch.
git diff "$PROD_SHA..HEAD" -- tools/demo-studio-v3/ | \
  grep -E "sk-ant-[A-Za-z0-9_-]{20,}|AIzaSy[A-Za-z0-9_-]{33}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----" \
  && echo "POTENTIAL SECRET LEAK — STOP" || echo "CLEAN"
```

Any match that is not a variable-name reference (e.g. appears in a `.py` string literal with a real-looking value) blocks the deploy.

### 1.6 Preflight gate summary — all must be GREEN

- [ ] §1.1 clean tree, branch confirmed, HEAD SHA recorded
- [ ] §1.3 pytest green (with documented exclusion)
- [ ] §1.4 no `tools.demo-studio-v3.*` imports
- [ ] §1.5 secret scan CLEAN on prod→HEAD diff
- [ ] Viktor confirms MAD.B / MAD.C / MAD.F complete on branch

---

## 2. Staging deploy

Single Cloud Run service — `demo-studio` in `mmpt-233505` / `europe-west1`. Deployed via `tools/demo-studio-v3/deploy.sh`. This is the canonical deploy script per ship ADR §6 and the existing workspace convention. The strawberry-agents `plans/in-progress/2026-04-17-deployment-pipeline.md` is for the **personal concern** (Firebase Hosting / myapps portal) — **not applicable** to this work deploy.

### 2.1 Required config env vars (non-secret, passed at deploy time)

```bash
export BASE_URL="https://demo-studio-stg-4nvufhmjiq-ew.a.run.app"   # confirm with Sona — staging URL
export MANAGED_AGENT_ID="agent_011Ca5KYp2DqkEe1U1W6matH"            # per docs/cloud-run-config-snapshot.md
export MANAGED_ENVIRONMENT_ID="env_018HE9PHNArMkj4g6eLqmfpZ"        # per docs/cloud-run-config-snapshot.md
export MANAGED_VAULT_ID="vlt_011Ca5KYhqukAQHrrW2dXWuQ"              # per docs/cloud-run-config-snapshot.md
```

**If staging uses a distinct `MANAGED_AGENT_ID` / env / vault** (preferred to avoid cross-env contamination), override here. Confirm with Sona before running.

**Secrets** (ANTHROPIC_API_KEY, SESSION_SECRET, INTERNAL_SECRET, WS_API_KEY, WALLET_STUDIO_API_KEY, DEMO_STUDIO_MCP_TOKEN, FIRECRAWL_API_KEY, DEMO_SERVICE_TOKEN, CONFIG_MGMT_TOKEN) are injected via Secret Manager references per `secrets-mapping.txt` — **never** passed on the command line. Verify `demo-runner-sa` has `secretAccessor` on all `DS_SHARED_*` and `DS_STUDIO_*` secrets:

```bash
gcloud secrets list --project=mmpt-233505 --filter='name~DS_(SHARED|STUDIO)_' --format='value(name)' | while read S; do
  gcloud secrets get-iam-policy "$S" --project=mmpt-233505 \
    --flatten=bindings \
    --filter='bindings.role:roles/secretmanager.secretAccessor AND bindings.members:serviceAccount:demo-runner-sa*' \
    --format='value(bindings.members)' | grep -q demo-runner-sa || echo "MISSING: $S"
done
```

Any `MISSING` line blocks deploy.

### 2.2 Run the staging deploy

```bash
cd /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-studio-v3

# Capture the pre-deploy revision for rollback reference.
PREV_REVISION=$(gcloud run services describe demo-studio \
  --project=mmpt-233505 --region=europe-west1 \
  --format='value(status.latestReadyRevisionName)')
echo "Pre-deploy revision: $PREV_REVISION"

# Deploy. deploy.sh reads secrets-mapping.txt, sets --set-env-vars, runs gcloud run deploy.
./deploy.sh

# Capture the new revision.
NEW_REVISION=$(gcloud run services describe demo-studio \
  --project=mmpt-233505 --region=europe-west1 \
  --format='value(status.latestReadyRevisionName)')
echo "Post-deploy revision: $NEW_REVISION"
echo "Rollback target if needed: $PREV_REVISION"
```

**Note on `deploy.sh`:** it uses `--source .` (Buildpack build from repo). Cold-build takes 3–6 min. The script does **not** pin `--min-instances` / `--max-instances` — see Blocker B4.

### 2.3 Staging deploy gate

- [ ] `gcloud run deploy` returned success (revision ready)
- [ ] `NEW_REVISION` recorded
- [ ] `PREV_REVISION` recorded for rollback
- [ ] Service URL resolves (below)

---

## 3. Staging smoke tests

### 3.1 Automated smoke — `scripts/smoke-test.sh`

The existing smoke script covers 8 HTTP probes: `/health`, `/debug`, `POST /session`, auth redirect, session page render, `/static/studio.js`, `/static/studio.css`, `/dashboard`. It does **not** cover MAD / MAL / terminate (Blocker B3).

```bash
cd /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-studio-v3

# INTERNAL_SECRET must match the staging secret. Fetch it short-lived:
export INTERNAL_SECRET=$(gcloud secrets versions access latest \
  --secret=DS_SHARED_INTERNAL_SECRET --project=mmpt-233505)

./scripts/smoke-test.sh "https://demo-studio-stg-4nvufhmjiq-ew.a.run.app"

# Expected final line: "Results: 8 passed, 0 failed"
unset INTERNAL_SECRET
```

### 3.2 Manual MAD/MAL surface verification (until B3 closed)

Until `tests/smoke/test_e2e_ship.py` is authored, operator performs these manually against stg:

1. **Dashboard Sessions tab** — open `<stg-url>/dashboard`. Confirm existing Sessions tab renders identically to prod (byte-regression surface — MAD.E.2).
2. **Dashboard Managed Agents tab** — only if `MANAGED_AGENT_DASHBOARD=1` was set on this deploy (see Blocker B5). Tab header appears; list populates; degradation pill shown if S2 is cold.
3. **Create-session lifecycle** — `POST /session` via the smoke flow above already covers this for SE: verify the Firestore doc in `demo-studio-sessions` has **no** `config` / `configVersion` / `brand` / `market` / `languages` / `shortcode` fields (BD Rule 1).
4. **Terminal-hook** — create a throwaway session, drive it to `completed` via the status-transition harness, confirm the Anthropic managed session returns 404 within 10s (requires `ANTHROPIC_API_KEY` bound). Out-of-band — not automatable without the missing smoke script.

### 3.3 Staging smoke gate

- [ ] `smoke-test.sh` 8/8 passed
- [ ] Manual §3.2 steps 1–3 verified
- [ ] §3.2 step 4 performed OR explicitly deferred (acceptable for dark-land per B5)

**STOP if any staging check is red.** Do not proceed to prod.

---

## 4. Prod deploy + smoke

Identical shape to staging, with a **human go/no-go** gate between.

### 4.1 Go/no-go

- [ ] Sona + Evelynn acknowledge staging green
- [ ] §0 Blockers accepted / mitigated
- [ ] Window timed to allow 30 min post-deploy observation (§5)
- [ ] Slack on-call aware; `#demo-studio-alerts` being watched

### 4.2 Prod env vars

```bash
export BASE_URL="https://demo-studio-4nvufhmjiq-ew.a.run.app"   # confirm prod URL with Sona
export MANAGED_AGENT_ID="agent_011Ca5KYp2DqkEe1U1W6matH"
export MANAGED_ENVIRONMENT_ID="env_018HE9PHNArMkj4g6eLqmfpZ"
export MANAGED_VAULT_ID="vlt_011Ca5KYhqukAQHrrW2dXWuQ"
```

If B4/B5 are being addressed in this deploy (operator decision), edit `deploy.sh` first to add the missing flags / env vars, commit as `ops:` (touches infra only), then proceed.

### 4.3 Prod deploy

```bash
cd /Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/tools/demo-studio-v3

PREV_REVISION=$(gcloud run services describe demo-studio \
  --project=mmpt-233505 --region=europe-west1 \
  --format='value(status.latestReadyRevisionName)')
echo "PROD pre-deploy revision: $PREV_REVISION"
# ^^ WRITE THIS DOWN in a Slack thread — it's the rollback target.

./deploy.sh

NEW_REVISION=$(gcloud run services describe demo-studio \
  --project=mmpt-233505 --region=europe-west1 \
  --format='value(status.latestReadyRevisionName)')
echo "PROD post-deploy revision: $NEW_REVISION"
```

### 4.4 Prod smoke

```bash
export INTERNAL_SECRET=$(gcloud secrets versions access latest \
  --secret=DS_SHARED_INTERNAL_SECRET --project=mmpt-233505)

./scripts/smoke-test.sh "https://demo-studio-4nvufhmjiq-ew.a.run.app"

unset INTERNAL_SECRET
```

**If `smoke-test.sh` reports `Results: N passed, M failed` with `M > 0` → immediate rollback per §6.2.**

### 4.5 Prod smoke gate

- [ ] Smoke 8/8 passed
- [ ] Manual MAD-tab verification per §3.2 on prod URL (read-only — do not create real sessions on prod)
- [ ] If MAD/MAL env vars set (B5), confirm `#demo-studio-alerts` has not received an error-spike slack

---

## 5. Post-deploy verification — first 30 min

Watch these after prod smoke passes. Logs in Cloud Logging (`resource.type=cloud_run_revision AND resource.labels.service_name=demo-studio`).

### 5.1 Error budget

```bash
# Error-rate sampling — 5 min windows, ×6 samples over 30 min.
gcloud logging read \
  'resource.type="cloud_run_revision" AND
   resource.labels.service_name="demo-studio" AND
   severity>=ERROR AND
   timestamp >= "'"$(date -u -v-5M +%Y-%m-%dT%H:%M:%SZ)"'"' \
  --project=mmpt-233505 --limit=100 --format='value(textPayload)' | wc -l
```

**Threshold:** >10 errors in any 5-min window → investigate / consider rollback.

### 5.2 Anthropic rate-limit health

Watch for `429` or `rate_limit_error` from the managed-agent surface. The MAL `stop_managed_session` wrapper and the MAD list handler both call Anthropic; a rate-limit storm indicates cache mis-configuration (relevant especially if B4 not addressed and Cloud Run scaled to >1 instance, breaking the MAD 10s TTL cache coherence).

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND
   resource.labels.service_name="demo-studio" AND
   (textPayload:~"rate_limit" OR textPayload:~"429" OR textPayload:~"anthropic.*error") AND
   timestamp >= "'"$(date -u -v-30M +%Y-%m-%dT%H:%M:%SZ)"'"' \
  --project=mmpt-233505 --limit=50
```

**Threshold:** any sustained 429 stream → rollback; isolated 429s are normal.

### 5.3 Firestore throughput

Cloud Monitoring → Firestore metrics (`firestore.googleapis.com/document/read_count`, `…/write_count`) filtered to `database_id=demo-studio-staging` (prod DB name per `deploy.sh` HEAD — verify).

**Baseline:** compare the 30-min post-deploy rate to the same window one day prior. >3× read rate with no traffic increase indicates cache miss storm (likely B4-related if MAD flag is on).

### 5.4 Managed-sessions cache hit rate (new in MAD.B.3)

If `MANAGED_AGENT_DASHBOARD=1`, the 10s TTL cache (`async_ttl_cache.py`) emits hit/miss logs. Pattern to grep:

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND
   resource.labels.service_name="demo-studio" AND
   (textPayload:~"ttl_cache.hit" OR textPayload:~"ttl_cache.miss") AND
   timestamp >= "'"$(date -u -v-15M +%Y-%m-%dT%H:%M:%SZ)"'"' \
  --project=mmpt-233505 --limit=1000 --format='value(textPayload)' \
  | awk '/ttl_cache.hit/{h++} /ttl_cache.miss/{m++} END{print "hits="h" misses="m" hit_rate="(h/(h+m+0.0001))}'
```

**Expected:** hit rate >0.7 under normal dashboard polling (10s TTL, ~6 polls/min per operator). <0.3 is anomalous — indicates the cache isn't sticky (likely multi-instance → B4).

### 5.5 MAL scanner heartbeat (if `MANAGED_SESSION_MONITOR_ENABLED=true`)

Scanner runs every `SCAN_INTERVAL_SECONDS` (default 300s). Should see one `scanner.tick` or equivalent log per interval.

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND
   resource.labels.service_name="demo-studio" AND
   textPayload:~"scanner|monitor.scan" AND
   timestamp >= "'"$(date -u -v-30M +%Y-%m-%dT%H:%M:%SZ)"'"' \
  --project=mmpt-233505 --limit=20
```

**Threshold:** expect ~6 ticks in 30 min (at 5-min interval). Zero ticks = scanner didn't start (check startup logs for exception).

### 5.6 30-min sign-off

- [ ] Error rate within budget
- [ ] No Anthropic 429 storm
- [ ] Firestore throughput within 1.5× baseline
- [ ] MAD cache hit rate >0.7 (if flag on)
- [ ] MAL scanner ticking (if flag on)
- [ ] No user reports in `#demo-studio-alerts`

---

## 6. Rollback decision tree

### 6.1 Rollback triggers — IMMEDIATE rollback (no forward-fix)

- Prod `smoke-test.sh` **any** failure
- 5xx rate >5% of requests over any 5-min window
- Anthropic 401/403 stream (secret binding broken)
- Firestore `permission_denied` stream (SA binding broken)
- Startup crash loop (revision serves 0 ready pods for >2 min)
- MAL scanner emits `AttributeError` / `TypeError` at startup (means SE/MAL integration broken)
- Any secret-value appearing in a log line (critical; rollback AND rotate)

### 6.2 Rollback procedure (manual — B1 blocker)

```bash
# PREV_REVISION was captured in §4.3. Recover if lost:
gcloud run revisions list --service=demo-studio \
  --project=mmpt-233505 --region=europe-west1 \
  --format='table(metadata.name,metadata.creationTimestamp,status.conditions[0].status)' \
  --sort-by=~metadata.creationTimestamp --limit=5

# Route 100% traffic back to the prior revision.
gcloud run services update-traffic demo-studio \
  --project=mmpt-233505 --region=europe-west1 \
  --to-revisions="$PREV_REVISION=100"

# Verify.
gcloud run services describe demo-studio \
  --project=mmpt-233505 --region=europe-west1 \
  --format='value(status.traffic[].revisionName,status.traffic[].percent)'

# Post to #demo-studio-alerts with: SHA rolled back from, SHA rolled back to,
# failure signature, owner (Duong / Heimerdinger / on-call).
```

Rollback SLA: <5 min from trigger detection. Traffic routing is instant; cache warmup on the old revision is typically <30s.

### 6.3 Forward-fix (no rollback) — acceptable cases

- Smoke step 8 (`GET /dashboard`) returns 500 **and** root cause is obviously a template/static-asset issue not affecting any API — acceptable to hotfix forward within 15 min
- MAD cache hit rate low but no user impact (B4 latent) — hotfix `deploy.sh` to pin instances, redeploy
- Scanner not ticking and flag is OFF — ignore until flag-flip PR
- `#demo-studio-alerts` receives duplicate slack warnings (B4 latent, multi-instance) — flip `MANAGED_SESSION_MONITOR_ENABLED=false` via `gcloud run services update … --update-env-vars …`; no redeploy required

### 6.4 Gray-zone — Heimerdinger / Duong call

- 5xx rate 1–5%: observe 10 min, rollback if not declining
- Single user report without reproducible log signature: investigate 15 min, rollback if no explanation
- Cache hit rate 0.3–0.7: not rollback-worthy but indicates B4; schedule pinning fix for next deploy

---

## 7. Artifacts to produce during/after deploy

- Pre-deploy HEAD SHA (from §1.1) → note in Slack thread
- Staging PREV_REVISION + NEW_REVISION (§2.2) → Slack thread
- Prod PREV_REVISION + NEW_REVISION (§4.3) → Slack thread
- Smoke-test outputs (stg + prod) → Slack thread
- 30-min observation summary (§5.6) → `assessments/work/post-deploy-2026-04-21.md` (Heimerdinger or on-call writes)
- If rollback occurred: post-mortem entry in `learnings/` within 24h (CLAUDE.md convention)

---

## Appendix A — Referenced paths

- Ship ADR: `/Users/duongntd99/Documents/Personal/strawberry-agents/plans/implemented/work/2026-04-21-demo-studio-v3-e2e-ship.md`
- Integration worktree: `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-integration/`
- Deploy script: `tools/demo-studio-v3/deploy.sh`
- Smoke script: `tools/demo-studio-v3/scripts/smoke-test.sh`
- Env validator: `tools/demo-studio-v3/scripts/validate-env.sh`
- Secrets mapping: `tools/demo-studio-v3/secrets-mapping.txt`
- Migration script (deferred to W8, not this ship): `tools/demo-studio-v3/scripts/migrate_session_status.py`
- Cloud Run snapshot doc: `tools/demo-studio-v3/docs/cloud-run-config-snapshot.md`

## Appendix B — Follow-up tasks (out of scope for today)

1. Author `tools/demo-studio-v3/tests/smoke/test_e2e_ship.py` implementing ship-ADR §5 scenarios S1–S10. Closes Blocker B3.
2. Author `scripts/deploy/rollback.sh` (either in workspace or strawberry-agents) per CLAUDE.md Rule 17. Closes Blocker B1.
3. Patch `tools/demo-studio-v3/deploy.sh` to pin `--min-instances=1 --max-instances=1` and add the W10 env vars per ship-ADR §6.3. Closes Blockers B4 + B5.
4. Install `.github/workflows/{e2e,tdd-gate}.yml` on the workspace repo once it is PR-gated. Closes Blocker B2.

---

*End of checklist. Written by Heimerdinger (advisor). Execution belongs to Ekko / on-call. No code or infra was modified in producing this document.*
