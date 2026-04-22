# Preview Service State Audit — 2026-04-22

Investigation task: report-only. No deploys, no patches applied.

---

## Repo Pull Status

### company-os (`~/Documents/Work/mmp/workspace/company-os/`)

- Fetched origin. Local branch is `feat/demo-studio-v3` (local HEAD: `12b9fd7`).
- Local state: clean (no uncommitted changes).
- `origin/main` HEAD: `013a15e` — "Merge pull request #49 from missmp/feat/demo-preview" (2026-04-21 10:18 +0700)
- `origin/feat/demo-studio-v3` HEAD: `0bb60d8` — "feat(demo-dashboard): W1 scaffold — new Cloud Run service skeleton (#65)" (2026-04-22 12:08 +0200)

### api (`~/Documents/Work/mmp/workspace/api/`)

- Fetched origin. Local state: clean.
- `origin/main` HEAD: `4056ac9` — "Merge pull request #40 from missmp/feat/demo-studio-openapi-specs"

---

## Q1: Current Prod Revision of demo-preview Cloud Run Service

| Field | Value |
|---|---|
| Service | demo-preview |
| Project | mmpt-233505 |
| Region | europe-west1 |
| Live revision | `demo-preview-00009-frw` |
| Traffic | 100% to `demo-preview-00009-frw` |
| Image digest | `sha256:a366a9f5ef0826eb1d7a765f6a8a3083bd47c3978bed8060cc5190cfee6f0ec6` |
| Image tag | `latest` |
| Deployed at | 2026-04-22T07:12:48.931472Z |
| Deployed by | `tuan.pham@missmp.eu` |

### Full revision history (last 9 revisions):

| Revision | Created (UTC) | Deployed by | Image digest (short) |
|---|---|---|---|
| `demo-preview-00009-frw` | 2026-04-22T07:12 | tuan.pham@missmp.eu | `a366a9f5` — **CURRENT LIVE** |
| `demo-preview-00008-6v6` | 2026-04-22T01:30 | duong.nguyen.thai@missmp.eu | `b0087a0161` |
| `demo-preview-00007-c7t` | 2026-04-22T01:16 | duong.nguyen.thai@missmp.eu | `d1209c1a7f` |
| `demo-preview-00006-57w` | 2026-04-21T14:07 | (via Azir deploy) | `8a68034d15` |
| `demo-preview-00005-ktj` | 2026-04-21T03:20 | pre-Azir | `61ea6f08ee` |
| `demo-preview-00004-xtc` | 2026-04-17T05:44 | — | `1149063e51` |
| `demo-preview-00003-gv7` | 2026-04-17T03:20 | — | `e38f097592` |
| `demo-preview-00002-znr` | 2026-04-16T10:51 | — | `e38f097592` |
| `demo-preview-00001-vhz` | 2026-04-16T10:31 | — | wallet-studio-mcp image |

**Revert revision identification:**
- Revisions `00007-c7t` and `00008-6v6` were both deployed by Duong between 01:16–01:30 UTC on 2026-04-22, from `feat/demo-studio-v3` commits `4e55a13` (/health) and `ddcea2a` (CORS on /health). These are the correct, intended code.
- Revision `00009-frw`, deployed by `tuan.pham` at 07:12 UTC, replaced those with an image built from `origin/main` — an older codebase. This is the **wrong deploy**. See Q5.

---

## Q2: Commit on company-os main Backing Current Prod Revision

The current live image (`sha256:a366a9f5`, artifact created 2026-04-22T14:12:24 UTC — note the artifact registry lists this as the `latest` tag) was deployed by Tuan from `origin/main`.

`origin/main` HEAD at the time was `013a15ef083e950d5b5a20e1c51738745b9be67d` — the merge commit that landed `feat/demo-preview` (PR #49) into main. The tip of that branch is `be0c6ae2eedbdf263d36e13f3a3f8b40578aa087` ("fix(demo-preview): align with Config Mgmt contract").

**Git SHA backing prod: `013a15e` (merge) / effective content from `be0c6ae`.**

Key implication: `origin/main` has the **old implementation** (`server.py`, Python `http.server`, Jinja2 templates, 550-line file). The active development branch `feat/demo-studio-v3` replaced this entirely with `main.py` (FastAPI/uvicorn, 341 lines, no templates directory).

Note: There is no deploy.sh on `origin/main` — the deploy to `00009-frw` was done directly via `gcloud run deploy --source .` from main, which picked up `server.py`, `templates/`, `static/`, `configs/`. The feat branch deploy.sh at `tools/demo-preview/deploy.sh` is only present on `feat/demo-studio-v3`.

---

## Q3: tools/demo-preview/ Code Survey

### Entry Points / Routes

**On `origin/main` (currently live in prod — `server.py`, `be0c6ae` content):**

| Path | Method | Auth | Notes |
|---|---|---|---|
| `/preview/{session_id}` | GET | None | Main iframe render. Accepts `?v=<int>` for cache-busting. Validates session_id against `^[a-zA-Z0-9_-]{1,128}$`. |
| `/health` | GET | None | Returns `{"status":"ok","service":"preview"}` |
| `/logs` | GET | Bearer PREVIEW_TOKEN | Queryable by session_id, level, since, limit |
| `/static/*` | GET | None | Static assets |
| `/` or `/index.html` | GET | None | Dev-only (when CONFIG_MGMT_URL unset) — lists local configs |
| `/preview?config=<name>` | GET | None | Dev-only — renders local config file |
| `/api/configs` | GET | None | Dev-only |
| `/api/config/<name>` | GET | None | Dev-only |

No `/fullview` route exists on `origin/main`. The fullview route was added in `feat/demo-studio-v3` (`773dd39`), merged to main via PR #55 on `feat/demo-studio-v3` only (not on `origin/main`).

**On `feat/demo-studio-v3` (what Duong's deploys 00007/00008 served — `main.py`):**

| Path | Method | Auth | Notes |
|---|---|---|---|
| `GET /health` | GET | None | FastAPI. Returns `{"status":"ok"}`. Has CORS headers (`Access-Control-Allow-Origin`). |
| `OPTIONS /health` | OPTIONS | None | Preflight CORS 204. |
| `GET /v1/preview/{session_id}` | GET | None | **Note path prefix change: `/v1/preview/` not `/preview/`.** Accepts `?v=<int>`. |
| `GET /v1/preview/{session_id}/fullview` | GET | None | Full-page HTML variant. |
| `GET /logs` | GET | Bearer PREVIEW_TOKEN | In-memory ring buffer, filterable. |

**Critical contract break:** The route changed from `/preview/{session_id}` (main) to `/v1/preview/{session_id}` (feat). The OpenAPI spec (`api/reference/5-preview.yaml`) uses `/preview/{session_id}` (no `/v1` prefix). The Studio UI would need to point to the right URL depending on which binary is live.

### Brand Resolution Code Path

**On `origin/main` (`server.py`):**
- `fetch_config_from_mgmt(session_id, version)` at line 86 calls `GET {CONFIG_MGMT_URL}/v1/config/{session_id}` (with optional `?v=<int>` appended).
- Falls back to `configs/{session_id}.json` local file if `CONFIG_MGMT_URL` is unset.
- Config returns `brand`, `colors`, `logos`, `card`, etc.
- `render_preview(config, config_version)` at line 147 uses Jinja2 templates from `templates/` directory.

**On `feat/demo-studio-v3` (`main.py`):**
- `_fetch_config(session_id, version)` at line 68 is a **TODO stub** — returns a hardcoded Allianz mock config. It does NOT call Config Mgmt yet.
- `_render_preview_body(session_id, config)` at line 107 renders inline CSS (no Jinja2 templates).

### Cache Layers

**Both branches:**
- Response headers: `Cache-Control: no-store` (main) / `Cache-Control: no-cache` (feat). No CDN caching.
- No in-process config cache on either branch. Every request re-fetches from Config Mgmt.
- Cloud Run warm instance: the in-memory `_logs` ring buffer persists across requests within a warm instance (up to 1000 entries). Not a config cache.
- No external CDN layer configured on the Cloud Run service.

The `?v=<int>` query param is purely cache-busting for the browser/iframe — the service itself ignores it for rendering and always fetches fresh config.

### deploy.sh

File: `tools/demo-preview/deploy.sh` (only on `feat/demo-studio-v3`, not on `origin/main`)

```
gcloud run deploy demo-preview \
  --source . \
  --project=mmpt-233505 \
  --region=europe-west1 \
  --set-secrets=PREVIEW_TOKEN=DS_PREVIEW_TOKEN:latest,CONFIG_MGMT_TOKEN=DS_CONFIG_MGMT_TOKEN:latest \
  --set-env-vars=CONFIG_MGMT_URL=https://demo-config-mgmt-266692422014.europe-west1.run.app \
  --no-allow-unauthenticated
```

Deploys from current working directory source using Cloud Build. No Docker build step — Cloud Run source deploy. The secret names match the current Secret Manager names (DS_PREVIEW_TOKEN, DS_CONFIG_MGMT_TOKEN — correctly set, unlike the config-mgmt deploy.sh that had the stale `ds-config-mgmt-token` name).

---

## Q4: API Repo — Preview Endpoint Contracts

File: `api/reference/5-preview.yaml` (HEAD: `4056ac9`)

### Endpoints

| Path | Method | Auth | Params | Response |
|---|---|---|---|---|
| `/preview/{session_id}` | GET | None (unauthenticated) | `session_id` (path, pattern `^[a-zA-Z0-9_-]{1,128}$`), `v` (query, integer, optional) | `200 text/html` with `X-Frame-Options: ALLOWALL`, `Cache-Control: no-store`. `404` if session not found. `503` if Config Mgmt unreachable. |
| `/preview/{session_id}/fullview` | GET | None (unauthenticated) | `session_id` (path) | `200 text/html`. Same 404/503 semantics. No `X-Frame-Options`. `Cache-Control: no-cache`. |
| `/logs` | GET | Bearer PREVIEW_TOKEN | `session_id` (query), `level` (query, enum info/warn/error), `since` (query, date-time), `limit` (query, int, default 100, max 1000) | `200 {service, logs[], total, hasMore}`. `401` on bad token. |

### Cache-Key Definition

No explicit cache-key definition in the spec. The `v` query param is described as: "Config version for cache busting. No effect on rendering — the service always fetches the latest config from Config Mgmt." The spec states the service always fetches fresh config (no server-side caching).

### Session ID + Brand as Params

- `session_id` is the only path param. Brand is not a query param — it is embedded in the config fetched from Config Mgmt by session_id.
- No `brand` param in the contract. Brand resolution is internal (Config Mgmt lookup by session_id).

### Version / Compatibility Notes

- Spec version: `1.0.0` (openapi 3.1.0).
- The spec uses `/preview/{session_id}` (no `/v1/` prefix). The `feat/demo-studio-v3` implementation uses `/v1/preview/{session_id}`. **This is a contract mismatch.** The spec needs to be updated OR the implementation path reverted to match the spec.
- The `origin/main` implementation (`server.py`) uses `/preview/{session_id}` — matching the spec.
- The `feat/demo-studio-v3` implementation (`main.py`) uses `/v1/preview/{session_id}` — NOT matching the spec.

---

## Q5: What Was Wrong About Yesterday's Deploy?

### Timeline reconstruction

| Time (UTC, 2026-04-22) | Event |
|---|---|
| 01:16 | Duong deploys `00007-c7t` from `feat/demo-studio-v3` commit `4e55a13` (/health endpoint added — Jayce-2 task). FastAPI/main.py codebase. |
| 01:30 | Duong deploys `00008-6v6` from `feat/demo-studio-v3` commit `ddcea2a` (CORS headers on /health). FastAPI/main.py codebase. |
| 07:12 | **tuan.pham deploys `00009-frw` from `origin/main`** — `server.py`/Jinja2/http.server codebase (be0c6ae content). This becomes 100% traffic. |

### What regressed

The `origin/main` codebase (`server.py`) that went live at 00009-frw is significantly older than what was running on 00007/00008:

1. **Missing /fullview route** — `origin/main` has no `/preview/{session_id}/fullview`. The Studio UI's "Open in fullview" button would 404.

2. **Wrong entrypoint** — `origin/main` runs `python server.py` (stdlib http.server, no uvicorn); the feat branch runs FastAPI via `python main.py`. The Dockerfile on main still copies `server.py`, `templates/`, `static/`, `configs/` — none of which exist in the feat branch tree.

3. **Missing CORS headers on /health** — `origin/main` /health has no CORS headers; the dashboard service probes /health cross-origin and would fail.

4. **Config Mgmt integration gap** — `origin/main`'s `server.py` does have real Config Mgmt integration (`fetch_config_from_mgmt`, line 86). The feat branch `main.py` has a `_fetch_config` stub returning a hardcoded Allianz config (TODO not yet implemented). This is actually the root of the preview-iframe-staleness problem: the feat branch never fetches real config.

5. **Runtime dependency mismatch** — `origin/main` requires only `jinja2`. The feat branch requires `fastapi`, `uvicorn`, `requests`, `jinja2`. Deploying main without the updated requirements.txt would crash at startup.

No revert commits were found in either branch's recent history. The `00009-frw` deploy was an overwrite, not a git revert. The "revert" to fix it would require redeploying from `feat/demo-studio-v3`.

**Root cause: tuan.pham ran `gcloud run deploy` from the `main` branch checkout rather than from `feat/demo-studio-v3`.**

---

## Q6: Deploy Guard Recommendations

### Option A: `.do-not-deploy` sentinel file in the service directory

Add a file `tools/demo-preview/.do-not-deploy` with contents explaining the constraint. Modify `deploy.sh` to check for it on any branch other than `feat/demo-studio-v3`:

```bash
if [ -f "$(dirname "$0")/.do-not-deploy" ]; then
  echo "ERROR: .do-not-deploy present. Deploy only from feat/demo-studio-v3."
  exit 1
fi
```

Pros: Visible in the working tree, survives branch switches, no env-var dependency, human-readable.
Cons: Anyone can delete the file or run `gcloud run deploy` directly (bypassing deploy.sh). Does not protect against Tuan-style deploys that bypass the script.

### Option B: Branch check inside deploy.sh

In `tools/demo-preview/deploy.sh`, add a guard at the top:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
ALLOWED="feat/demo-studio-v3"
if [ "$BRANCH" != "$ALLOWED" ]; then
  echo "ERROR: Must deploy from '$ALLOWED'. Current branch: '$BRANCH'." >&2
  exit 1
fi
```

Pros: Automatic, no extra files, git-native. Enforces at the script level.
Cons: Bypassed if someone runs `gcloud run deploy --source .` directly without using deploy.sh. Does not help if the script is not used.

### Option C: Service-level IAM restriction + human process

Restrict `roles/run.developer` on the `demo-preview` service specifically to Duong's identity only (remove from tuan.pham or other contributors) until `feat/demo-studio-v3` merges to main and the two codebases unify.

```bash
gcloud run services add-iam-policy-binding demo-preview \
  --region=europe-west1 \
  --project=mmpt-233505 \
  --member=serviceAccount:... \
  --role=roles/run.developer
```

Pros: Enforced at the GCP control plane — no way to bypass via script modifications. Hardest guard.
Cons: Requires IAM admin access (blocked for current identities — needs project Owner). Operational friction if Tuan needs to redeploy other services. Does not scale.

### Recommendation

**Combine B + partial A:** Add the branch check to `deploy.sh` (Option B) as an immediate no-cost guard, and add a `tools/demo-preview/DEPLOY-NOTE.md` (not a sentinel file, just documentation) explaining that this service must be deployed from `feat/demo-studio-v3` until further notice. This is the minimum viable guard implementable without IAM changes or new files that need tracking.

The longer-term fix is to merge `feat/demo-studio-v3` into `origin/main` so there is only one source of truth, eliminating the branch ambiguity entirely.

---

## Summary of Key Findings

| Item | Finding |
|---|---|
| Live revision | `demo-preview-00009-frw` — wrong codebase (origin/main) |
| Live commit | `013a15e` (company-os origin/main, merged 2026-04-21) |
| Live implementation | `server.py` + Jinja2 templates + stdlib http.server |
| Intended implementation | `main.py` + FastAPI + uvicorn (on feat/demo-studio-v3) |
| Missing in live | `/fullview` route, CORS on /health, correct Dockerfile |
| Config Mgmt integration | Live (origin/main) HAS it; feat branch main.py has a TODO stub |
| Route contract mismatch | Spec says `/preview/{id}`; feat branch uses `/v1/preview/{id}` |
| Cache layers | None server-side. Browser cache-bust via `?v=`. No CDN. |
| Root cause of wrong deploy | tuan.pham deployed from origin/main instead of feat/demo-studio-v3 |
| Deploy guard needed | Yes — branch check in deploy.sh minimum |
