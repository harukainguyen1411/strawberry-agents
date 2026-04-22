---
status: proposed
orianna_gate_version: 2
concern: work
complexity: complex
tests_required: true
owner: swain
created: 2026-04-22
estimate_minutes: 60
tags:
  - demo-studio-v3
  - demo-factory
  - s1
  - s3
  - factory-bridge
  - wallet-studio
  - ipad-demo
  - p1
  - work
architecture_impact: structural
architecture_changes:
  - Replaces S1 `factory_bridge_v2.trigger_factory_v2` scaffold with a real HTTP client calling S3 `POST /build`.
  - Replaces S3 `_run_build_job` mock in `tools/demo-factory/main.py` with a real WS-driven pipeline invocation refactored out of `tools/demo-factory/factory.py`.
  - Adds S2 config fetch inside S3 (S3 gains a `config_mgmt_client.py`) so the factory pipeline receives brand/market/colors/logos/card/params/journey/tokenUi/ipadDemo from demo-config-mgmt rather than a Claude research step.
  - Adds session fields `demoUrl`, `projectUrl`, `shortcode`, `buildId` (alongside existing `projectId`, `outputUrls`, `factoryRunId`) and whitelists them in `session._UPDATABLE_FIELDS`.
  - Adds a "Demo ready" completion panel to S1 `static/studio.js` rendering a clickable iPad demo link and Wallet Studio project link when `status=complete`.
orianna_signature_approved: "sha256:81128a9f5e1883f2a51b0e1fb261e6253b8cee0d62fd0d07fabc595f74865b83:2026-04-22T14:44:17Z"
---

# ADR: P1 — User triggers build → finished Wallet Studio project + iPad demo link

<!-- orianna: ok — all module and repo paths cited below (company-os/tools/demo-studio-v3/, company-os/tools/demo-factory/, company-os/tools/demo-config-mgmt/) are mmp/company-os work-workspace files; this plan is planning-only and introduces no strawberry-agents local files under those names -->
<!-- orianna: ok — HTTP route tokens (/session/{id}/build, /build, /build/{buildId}, /build/{buildId}/events, /v1/config/{id}) are Cloud Run service endpoints, not filesystem paths -->
<!-- orianna: ok — Firestore collection paths (demo-studio-sessions, demo-factory-builds, demo-factory-projects) are Firestore collection paths, not filesystem paths -->
<!-- orianna: ok — Python stdlib and library identifiers (httpx.AsyncClient, asyncio.create_task, BackgroundTasks, StreamingResponse, firestore.SERVER_TIMESTAMP) are Python symbols, not filesystem paths -->
<!-- orianna: ok — MIME type tokens (text/event-stream, application/json) are content-type strings, not filesystem paths -->
<!-- orianna: ok — Wallet Studio URL patterns (app.walletstudio.com/projects/{id}, demo.missmp.tech/{shortcode}) are deployed-service URLs, not filesystem paths -->

## Context

Priority-1 goal: **a user who clicks "Build" in demo-studio-v3 ends up, a few minutes later, with a real Wallet Studio project and a clickable iPad demo link.** Today neither endpoint produces a real artifact.

Verified facts (as of 2026-04-22, worktree `company-os/` on branch `feat/demo-studio-v3`, HEAD `39c60cf`): <!-- orianna: ok -- work-workspace path, not strawberry-agents -->

- **S1 `POST /session/{sid}/build`** in `company-os/tools/demo-studio-v3/main.py` line ~2129 is internal-secret gated, transitions the session `configuring→building`, and awaits `factory_bridge_v2.trigger_factory_v2(...)`. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- **`company-os/tools/demo-studio-v3/factory_bridge_v2.py` line 17** is a pure scaffold: generates `run_id = uuid.uuid4().hex[:12]`, writes `factoryRunId` on the session, and returns `{ok, factoryRunId, projectId}` where `projectId` is synthetic (`f"proj-{session_id[:8]}"`). `TODO(BD.F.2)` marks the missing HTTP call. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- **S3 `company-os/tools/demo-factory/main.py` `_run_build_job`** (line 356) is a 100 % mock: steps through `PIPELINE_STEPS` with `asyncio.sleep(0.01)` per step, never touches Wallet Studio, returns `projectUrl: https://app.walletstudio.com/projects/{proj-uuid}` and `demoUrl: https://demo.missmp.tech/{proj-uuid}` derived from a synthetic uuid, not a real shortcode. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- **S3 has no S2 client** — `grep -rn CONFIG_MGMT tools/demo-factory/` returns nothing. The mock does not need config; the real pipeline will. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- **The real pipeline exists** — `company-os/tools/demo-factory/factory.py` is a CLI (`python factory.py run --brand Agila --line pet`) that drives `WSClient` (`ws_client.py`, reading `WS_BASE_URL` + `WS_API_KEY`) through: `create_project → post_clone_fixup → set_project_images → apply_ios_template → apply_google_template → apply_params → apply_translation_keys → apply_journey_actions → apply_token_ui → sync_pass_preview → create_test_pass → publish_ios_template` (indirectly via apply). It assembles `content` from `research_brand` (LLM) → `generate_strategy` → `generate_content`. This LLM research stage is the wrong input surface for P1 — the user already provided brand/market/config in S2. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- **iPad demo URL pattern** — real demos resolve at `https://demo.missmp.tech/{shortcode}` where `shortcode` is a human-readable slug (e.g. `agila-pet`) written on the WS project via `WSClient.update_project`. The shortcode is initially set by `post_clone_fixup` in `company-os/tools/demo-factory/project.py` line 77 from `demo.get("shortcode")`. It is readable via `client.get_project(project_id)["shortcode"]`. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- **S4 auto-trigger is disabled in practice** — `S4_VERIFY_URL` env var is unset on the deployed S3 instance, so `_trigger_s4` logs a warning and no-ops. P1 does **not** include S4; that is P3. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- **S1→S3 SSE relay** (`s3_build_sse_stream` in S1 `main.py` line 175) already exists but cannot work today because `factoryRunId` is a synthetic 12-hex id, not a real S3 `buildId`. Once S3 returns real `buildId`, the relay begins functioning. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- **S2 config shape** (`company-os/tools/demo-config-mgmt/main.py` MOCK_CONFIG, line 39): `{brand, market, languages, shortcode, colors, logos, card, params, ipadDemo, journey, tokenUi}`. This aligns strongly with the `content` dict that the real factory pipeline expects (brand/market/languages/shortcode/colors/logos/card/params/journey/tokenUi). Minor deltas: S2 has `ipadDemo`; factory content has `demoSteps`/`steps`/`persona`/`translations`/`insuranceLine`. These deltas are resolved in §D3 below. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- **S1 UI surface for completion** — `company-os/tools/demo-studio-v3/static/studio.js` lines 852-862: when the Firestore snapshot reports `status==='complete'` and `outputUrls.demoUrl` is truthy, it `addMessage('system', 'Demo deployed: ' + d.outputUrls.demoUrl)`. That writes the URL as plain text into the chat stream with no click affordance. P1 requires a clickable link, so a proper "Demo ready" panel must be added. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- **Session schema** — `session._UPDATABLE_FIELDS` at line 177 of `company-os/tools/demo-studio-v3/session.py` already includes `projectId`, `factoryRunId`, `outputUrls`. New fields (`buildId`, `demoUrl`, `projectUrl`, `shortcode`) must be added to the allowlist before any writer can set them; `update_session_field` raises `ValueError` otherwise. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->

Orthogonal concerns explicitly **out of scope**: S4 verification (P3), Slack surfacing removal (Loop 2d — a separate Firebase Auth loop), WS template/theme changes, preview iframe staleness, dashboard health CORS. Any of these can land independently; P1 does not gate on them and does not gate them.

## Decision

### D1. Scope decision — MVP path, not full-pipeline

Two shapes were considered:

- **D1.a — Full real pipeline.** S3 calls the existing `factory.py` pipeline end-to-end: Claude research → strategy → content generation → WS write → publish → return real shortcode + URLs. <!-- orianna: ok — factory.py is a CLI in company-os/tools/demo-factory/, not a strawberry-agents file -->
- **D1.b — MVP with S2 config as source of truth.** S3 creates a real WS project from the S2 config (brand/market/colors/logos/card/params/journey/tokenUi/ipadDemo/shortcode), applies the template, publishes, returns the real shortcode and URLs. No LLM research step inside the build. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- **D1.c — Thin mock + synthetic real-looking URL.** Leave `_run_build_job` as a mock but return `https://demo.missmp.tech/{slug}` derived from the S2 `shortcode`. Fastest but still no real project.

**Decision: D1.b (MVP, S2 config as source of truth).** Rationale:

1. Duong's acceptance test is "user clicks build, gets a real clickable iPad demo link." D1.b delivers that with a real WS project behind the URL.
2. D1.a duplicates decision-making already made by the user in S2 chat. The research/strategy/generate stages re-derive brand/market/colors/persona from the web, which contradicts the user's explicit S2 inputs.
3. D1.a depends on Claude API availability, research pipeline correctness, and LLM content-generation quality — a three-way coin flip per build run. D1.b has no LLM hop and is deterministic given the S2 config.
4. D1.c does not produce a real Wallet Studio project, violating the acceptance criterion.

The LLM pipeline is not deleted; it remains available as the CLI (`python factory.py run --brand ...`) for bespoke demo generation outside the studio flow. The new S3 code path is a **peer** to `factory.py`, not a replacement. <!-- orianna: ok — factory.py is company-os/tools/demo-factory/factory.py, a work-workspace CLI, not a strawberry-agents file -->

### D2. S1 → S3 HTTP contract

**Endpoint:** `POST {S3}/build` (already exists, body schema is `BuildRequestV2`). <!-- orianna: ok -- work-workspace path, not strawberry-agents -->

**Request body (sent by S1 `factory_client_v2.start_build`):**

```json
{
  "sessionId": "<hex session id>",
  "projectId": "<string, optional — present on iteration rebuilds>",
  "configVersion": 3
}
```

**Response body (sync, returned immediately; build runs async):**

```json
{
  "buildId": "build-abc123def456",
  "projectId": "10793"
}
```

`projectId` is the **real WS numeric project id** on the first build (e.g. `"10793"`), or echoed back on iteration rebuilds. It is **not** a UUID. S1 persists `projectId` and `buildId` on the session doc.

**Terminal state discovery (S1):** S1 subscribes to `GET {S3}/build/{buildId}/events` SSE (already wired in `s3_build_sse_stream`). When S3 emits `build_complete` with payload `{buildId, projectId, shortcode, projectUrl, demoUrl}`, S1 writes the URLs to the session doc. When S3 emits `build_failed`, S1 transitions `building→failed`. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->

**S3 `build_complete` event payload schema (extended):**

```json
{
  "buildId": "build-abc123def456",
  "projectId": "10793",
  "shortcode": "agila-pet-10793",
  "projectUrl": "https://app.walletstudio.com/projects/10793",
  "demoUrl": "https://demo.missmp.tech/agila-pet-10793",
  "passUrls": {
    "apple": "https://app.walletstudio.com/pass/10793/apple",
    "google": "https://app.walletstudio.com/pass/10793/google"
  }
}
```

Current mock emits the same keys but derives values from a synthetic uuid. D2 keeps the key shape so no S1 parser changes are needed — only the values become real.

**Auth:** existing scheme unchanged. S1 → S3 passes `Authorization: Bearer ${FACTORY_TOKEN}` (S3 `_require_auth`, line 54). S3 → S1 callback is not in scope for P1 (S1 polls/subscribes via SSE; no push). S2 fetch from S3 uses S2's bearer token (`CONFIG_MGMT_TOKEN`). Internal-secret hop (S1 inbound from Slack/UI) stays on the S1 side only. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->

**Timeouts:**

- S1 → S3 `POST /build` synchronous call: 30 s. The endpoint returns after project-lookup only, so 5 s is the expected p99; 30 s accommodates a cold-start on S3 Cloud Run. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- S1 → S3 SSE subscribe: `httpx.AsyncClient` with no overall timeout; read timeout 30 s (matches the current pattern, tolerates pipeline step latency). <!-- orianna: ok — httpx.AsyncClient is a Python class identifier, not a filesystem path -->
- S3 → WS (per call inside build job): `WSClient` defaults to 30 s per request (`ws_client.py` line 43). No change. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- Overall build wall-clock ceiling (S3 internal): 10 min. If exceeded, S3 emits `build_failed` with reason `timeout`. Matches the existing 5-min SSE client ceiling in `get_build_events` line 577; extended to 10 min for real builds. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->

**Retry policy:**

- S1 → S3 `POST /build`: 1 attempt. Non-idempotent (creates projects), so no automatic retry. On 5xx, S1 propagates to the user as 502 with a retry-this-manually message. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- S3 → WS: existing `WSClient` retry policy (2 retries on 5xx with 1 s/2 s backoff) is retained unchanged. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- S3 → S2: 1 attempt, 10 s timeout. On failure, S3 emits `build_failed` with reason `config_fetch_failed`; no partial build.
- S1 → S3 SSE reconnect: existing behaviour — S1 closes the stream on user navigation; SSE auto-reconnect is not added (out of scope).

### D3. S3 build-handler refactor — library extraction

Move the real pipeline from `factory.py` into an importable library so `main.py` can call it without shelling out. <!-- orianna: ok — factory.py and main.py are company-os/tools/demo-factory/ files, not strawberry-agents files -->

**New module: `company-os/tools/demo-factory/factory_build.py`.** <!-- orianna: ok -- work-workspace path, not strawberry-agents --> Exports one function:

```python
async def run_build_from_config(
    build_id: str,
    session_id: str,
    project_id: str | None,
    config: dict,
    event_sink: Callable[[str, dict], None],
) -> dict:
    """Run a real WS build using the supplied S2 config.

    Returns {projectId, shortcode, projectUrl, demoUrl, passUrls, configVersion}
    on success; raises BuildFailed on any step failure.

    event_sink is called with (event_type, payload) for each step_start /
    step_complete event; the caller wires it to _append_build_event.
    """
```

**Why a new module, not `factory.py` directly:** `factory.py` is a CLI (`argparse`, `sys.exit`, subprocess `open` call on the review page, LLM research step, cache directories under `demos/{slug}/.factory/`). Reusing it as a library would require un-CLIifying it. Cleaner to extract only the WS-apply steps (steps 6a–6h, 7, 8 in §D3.1) into the new module. The LLM steps 1–3 (research/strategy/content) are **dropped** from the build hot path — their output is replaced by the S2 config. <!-- orianna: ok — factory.py/sys.exit/demos/{slug}/.factory/ are all company-os/tools/demo-factory/ identifiers, not strawberry-agents files -->

**D3.1 — Steps in `run_build_from_config`:**

1. `fetch_config_from_s2(session_id)` (unless `config` already supplied by caller)
2. `content = s2_config_to_factory_content(config)` — translation (see D3.2)
3. If `project_id is None`: `create_project(client, content)` → new project, get numeric id
4. `post_clone_fixup(client, project_id, content)` — shortcode set here (`demo.get("shortcode")` with numeric suffix on conflict)
5. `upload_logo(client, project_id, wordmark_src, bg_color)` — fetch logo bytes from `content.logos.wordmark` URL; no pre-rendered PNG needed for MVP <!-- orianna: ok — content.logos.wordmark is a Python dict key path, not a filesystem path -->
6. `apply_ios_template(client, project_id, content)`
7. `apply_google_template(client, project_id, content)`
8. `apply_params(client, project_id, content)`
9. `apply_translation_keys(client, project_id, content)`
10. `apply_journey_actions(client, project_id, content)` — capture action_ids into `demoSteps.steps[i].journeyActionId`
11. `apply_token_ui(client, project_id, content)`
12. `sync_pass_preview(client, project_id)`
13. `client.publish_ios_template(project_id)`
14. `snapshot = client.get_project(project_id)` → read final `shortcode`
15. Compose and return URLs

Each step calls `event_sink("step_start", {...})` and `event_sink("step_complete", {...})`. No visual QA (step 8 in factory.py), no Playwright render, no review HTML — these are out of scope for the build hot path. <!-- orianna: ok — factory.py is company-os/tools/demo-factory/factory.py, work-workspace CLI -->

**D3.2 — S2 config → factory `content` translation.**

```python
def s2_config_to_factory_content(cfg: dict) -> dict:
    """Map S2 DemoConfig → factory `content` shape.

    Direct carry: brand, market, languages, shortcode, colors, logos, card, params, journey, tokenUi.
    Derived:
      - insuranceLine: cfg.get("insuranceLine", "") — empty default OK
      - persona: cfg.get("persona", {}) — empty default OK; apply_params handles absence
      - translations: cfg.get("translations", {})
      - demoSteps: map cfg.ipadDemo.steps → {heading, scanLabel, phonePrimary, steps:[...]}
    """
```

Fields in factory `content` that have no S2 counterpart receive empty defaults; the corresponding WS-apply functions already handle empty inputs defensively (validated by reading `tools/demo-factory/apple.py`, `gpay.py`, `journey.py`). Any S2 config missing required fields (`brand`, `market`, `colors.primary`, `logos.wordmark`, `shortcode`) yields a validation error before step 3 — build fails fast with reason `config_invalid`. <!-- orianna: ok — apple.py/gpay.py/journey.py are company-os/tools/demo-factory/ files; colors.primary/logos.wordmark are S2 config dict key paths, not filesystem paths -->

**D3.3 — Wire-up in `main.py`.** <!-- orianna: ok — main.py refers to company-os/tools/demo-factory/main.py, work-workspace file -->

```python
# company-os/tools/demo-factory/main.py (rewrite _run_build_job)
from factory_build import run_build_from_config, BuildFailed
from config_mgmt_client import fetch_config, NotFoundError, ServiceUnavailableError

async def _run_build_job(build_id: str, session_id: str, project_id: str | None) -> None:
    _builds[build_id]["status"] = "running"
    _append_build_event(build_id, "build_started", {"buildId": build_id, "sessionId": session_id})
    try:
        cfg_response = fetch_config(session_id)
        cfg = cfg_response.get("config") or {}
        cfg_version = cfg_response.get("version")
    except (NotFoundError, ServiceUnavailableError, Exception) as exc:
        _builds[build_id]["status"] = "failed"
        _append_build_event(build_id, "build_failed", {"reason": "config_fetch_failed", "detail": exc.__class__.__name__})
        return

    def _sink(ev_type: str, payload: dict) -> None:
        _append_build_event(build_id, ev_type, payload)

    try:
        result = await run_build_from_config(build_id, session_id, project_id, cfg, _sink)
    except BuildFailed as exc:
        _builds[build_id]["status"] = "failed"
        _append_build_event(build_id, "build_failed", {"reason": exc.reason, "detail": exc.detail})
        return
    except Exception as exc:
        _builds[build_id]["status"] = "failed"
        _append_build_event(build_id, "build_failed", {"reason": "unexpected", "detail": exc.__class__.__name__})
        return

    _builds[build_id]["status"] = "success"
    _builds[build_id]["projectId"] = result["projectId"]
    _builds[build_id]["configVersion"] = cfg_version
    _append_build_event(build_id, "build_complete", {
        "buildId": build_id,
        "projectId": result["projectId"],
        "shortcode": result["shortcode"],
        "projectUrl": result["projectUrl"],
        "demoUrl": result["demoUrl"],
        "passUrls": result["passUrls"],
        "configVersion": cfg_version,
    })
```

**D3.4 — S3 blocking call note.** `run_build_from_config` calls synchronous `requests` via `WSClient`. Running under asyncio, this blocks the event loop for the duration of each HTTP call. Acceptable for P1 (builds are rare, one at a time per session, Cloud Run gives each instance isolated concurrency). If this becomes a bottleneck in a later phase, wrap WS calls via `asyncio.to_thread(...)`. For P1, mark as a known TODO in code comments, not a blocker.

### D4. Shortcode → URL resolution

**Where the shortcode comes from:** `post_clone_fixup` (step 4 in D3.1) writes `demo.get("shortcode")` to the WS project. If the shortcode conflicts (another project has it), WS returns an error and fixup retries with `f"{shortcode}-{project_id}"` (existing logic in `project.py` lines 76-90). So the **effective shortcode** is only known after fixup.

**When URLs are composed:** after step 14 (`get_project(project_id)`), read `snapshot["shortcode"]` and compose:

- `projectUrl = f"https://app.walletstudio.com/projects/{project_id}"`
- `demoUrl = f"https://demo.missmp.tech/{effective_shortcode}"`
- `passUrls.apple = f"https://app.walletstudio.com/pass/{project_id}/apple"`
- `passUrls.google = f"https://app.walletstudio.com/pass/{project_id}/google"`

**URL hostnames are hardcoded for MVP.** A follow-up (not in P1) should move them to env vars (`WS_APP_BASE_URL`, `DEMO_BASE_URL`) for staging/prod parity. Flagged as OQ-6.

### D5. S1 session-state persistence and UI surface

**Session doc — new fields (written by S1 after observing the SSE `build_complete` event from S3):**

| Field | Type | Set by | When |
|---|---|---|---|
| `projectId` | string (numeric WS id) | S1 `build_session` handler | Sync, from S3 `POST /build` response (existing behaviour — value becomes real not synthetic) |
| `buildId` | string | S1 `build_session` handler | Sync, from S3 `POST /build` response (NEW) |
| `shortcode` | string | S1 SSE relay | Async, on `build_complete` event |
| `projectUrl` | string (URL) | S1 SSE relay | Async, on `build_complete` event |
| `demoUrl` | string (URL) | S1 SSE relay | Async, on `build_complete` event |
| `outputUrls` | object `{demoUrl, projectUrl, passUrls}` | S1 SSE relay | Async, on `build_complete` event |
| `status` | `complete` / `failed` | S1 SSE relay | Async, on terminal event |

**`session._UPDATABLE_FIELDS` allowlist** at line 177 must grow to include: `buildId`, `shortcode`, `projectUrl`, `demoUrl`. `outputUrls`, `projectId`, `factoryRunId` are already there. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->

**`factoryRunId` deprecation.** Today `factory_bridge_v2` writes a synthetic uuid into `factoryRunId`. Under P1, `factoryRunId` is replaced by `buildId` (real S3 build id). Keep the column for one release for backward-compat reads; stop writing it. Follow-up plan removes it.

**UI — "Demo ready" panel (S1 `static/studio.js`).**

Current behaviour (line 860): `if (d.outputUrls && d.outputUrls.demoUrl) addMessage('system', 'Demo deployed: ' + d.outputUrls.demoUrl);`. This writes the raw URL into the chat as system text — not clickable, buried in scroll.

Replace with a persistent panel rendered at the top of the session view when `d.status === 'complete'`:

- Heading: "Demo ready"
- Primary CTA button: "Open iPad demo" → `href = d.outputUrls.demoUrl` (`target="_blank" rel="noopener noreferrer"`)
- Secondary link: "View in Wallet Studio" → `href = d.outputUrls.projectUrl`
- Subtle copy-to-clipboard icon next to the demo URL (non-blocking affordance)
- Render in the existing sidebar or above the chat log; Lulu/Neeko pick-me-up in §Test-plan

The chat-line "Demo deployed: ..." message may stay as a historical artifact in the chat log, or be removed — Lulu decides.

### D6. Error paths

Build failure surfaces via a single S3 event type `build_failed` with a `reason` enum. S1 translates to session `status=failed` and a user-facing message. Error taxonomy:

| Reason | Trigger | User-facing message |
|---|---|---|
| `config_fetch_failed` | S3 → S2 fetch 5xx, network, or missing session id | "Could not load configuration. Try again." |
| `config_invalid` | S2 config missing required fields (`brand`, `colors.primary`, `logos.wordmark`, `shortcode`) | "Configuration is incomplete: <field list>. Fix and rebuild." | <!-- orianna: ok — colors.primary/logos.wordmark are S2 config dict key paths, not filesystem paths -->
| `ws_api_failed` | Any WS call 4xx/5xx after retry exhausted | "Wallet Studio build failed at step <name>. Try again." |
| `timeout` | Build exceeds 10 min wall-clock | "Build timed out. Try again." |
| `unexpected` | Any uncaught exception | "Unexpected error. Try again." |

**Partial-build recovery.** If the pipeline fails after `create_project` but before `publish_ios_template`, the project exists but is not published. S1 stores `projectId` on the session from the sync S3 response. On the user's next build click, S1 sends `{sessionId, projectId}`; S3 re-uses the project (existing `/build` behaviour — validates the projectId exists in `_projects` or Firestore). This means a retry after partial failure picks up where the pipeline left off for the `create_project` step. Later steps are idempotent (all WS writes are full-object PUTs per `ws_client.py` comments) so re-running the full pipeline against the existing project is safe. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->

**Orphan projects.** If a user abandons a build mid-flight and the project is never re-used, it leaks. Not resolved in P1 (matches the `s3-project-reuse-and-s4-trigger` stance). Track as OQ-4.

**S4 no-op.** S4 auto-trigger stays disabled (`S4_VERIFY_URL` unset in prod). The call still fires on build success but `_trigger_s4` logs a warning and returns without error. Build terminal state is independent of S4. <!-- orianna: ok -- work-workspace path, not strawberry-agents -->

### D7. Deploy & flags

No new env vars beyond what exists. Rollout is a two-revision Cloud Run deploy:

1. Deploy S3 revision with `_run_build_job` rewrite **behind a boolean env flag** `FACTORY_REAL_BUILD=1`. When unset, fall through to the existing mock. Canary traffic-split: 10 % with flag on, 90 % mock, for 24 h.
2. Flip to 100 % with flag on. Remove mock code in a follow-up commit one week later.

S1 deploy is feature-gated via the same observable behaviour — S1 cares about real `buildId` and real URLs, which it will only see when the S3 instance it hits has the flag on. Not mutually exclusive.

**Rollback.** Revert the S3 Cloud Run revision. S1's session field writes are backward-compatible (the new fields are ignored when absent; the existing `outputUrls` key is the only one the UI reads today).

### D8. Scope fence — explicit out-of-scope

- S4 verification hop (P3)
- Slack surfacing removal (Loop 2d)
- Anthropic managed-agent path, demo-studio-mcp deprecation (Vanilla-API ADR)
- Firebase Auth integration (separate loop)
- iPad demo content quality (rendering, persona dataset, journey content) — driven entirely by S2 config; not P1's responsibility
- Dashboard health CORS proxy
- Preview iframe staleness
- S3 Firestore rehydration robustness (already in `s3-project-reuse-and-s4-trigger`)
- Post-deploy smoke tests on prod (rule 17 applies but is its own concern)

## Tasks

Aphelios owns task breakdown. Each task below is sized approximately; Aphelios rescopes to 20–60 min tranches with xfail-first discipline per rule 12.

- [ ] **T.P1.1** — xfail contract test: S3 `POST /build` returns real `buildId` + `projectId` when `FACTORY_REAL_BUILD=1` and S2 config present; asserts no synthetic uuid in response — kind: test | estimate_minutes: 30
- [ ] **T.P1.2** — Implement `company-os/tools/demo-factory/config_mgmt_client.py` (copy/adapt from S1's) — kind: code | estimate_minutes: 25 <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- [ ] **T.P1.3** — Extract `run_build_from_config` into `company-os/tools/demo-factory/factory_build.py`; library-only, no CLI — kind: code | estimate_minutes: 55 <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- [ ] **T.P1.4** — Implement `s2_config_to_factory_content` translator with full test coverage for shape alignment — kind: code+test | estimate_minutes: 45
- [ ] **T.P1.5** — Rewrite `_run_build_job` in `company-os/tools/demo-factory/main.py` behind `FACTORY_REAL_BUILD` flag — kind: code | estimate_minutes: 40 <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- [ ] **T.P1.6** — Extend `build_complete` event payload to include `shortcode`, `projectUrl`, `demoUrl`, `passUrls` with real values — kind: code | estimate_minutes: 20
- [ ] **T.P1.7** — xfail contract test: S3 emits `build_failed` with each of the five `reason` values under forced failure conditions — kind: test | estimate_minutes: 40
- [ ] **T.P1.8** — Implement `company-os/tools/demo-studio-v3/factory_client_v2.py` with `httpx.AsyncClient` calling S3 `POST /build` — kind: code | estimate_minutes: 30 <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- [ ] **T.P1.9** — Rewrite S1 `factory_bridge_v2.trigger_factory_v2` to call `factory_client_v2.start_build` and return `{ok, buildId, projectId}` — kind: code | estimate_minutes: 25
- [ ] **T.P1.10** — Extend S1 SSE relay (`s3_build_sse_stream` → session doc writer) to parse `build_complete` and write `shortcode`, `projectUrl`, `demoUrl`, `outputUrls`, transition to `complete` — kind: code | estimate_minutes: 35
- [ ] **T.P1.11** — Extend `session._UPDATABLE_FIELDS` allowlist with `buildId`, `shortcode`, `projectUrl`, `demoUrl` — kind: code | estimate_minutes: 10
- [ ] **T.P1.12** — xfail integration test: S1 `POST /session/{id}/build` → S3 real pipeline → real WS project → real shortcode returned; assert session doc has `status=complete` and `outputUrls.demoUrl` matches `https://demo.missmp.tech/...` — kind: test | estimate_minutes: 50 <!-- orianna: ok — outputUrls.demoUrl is a Firestore session doc field key path, not a filesystem path; demo.missmp.tech is a deployed-service URL, already suppressed above -->
- [ ] **T.P1.13** — Replace S1 `static/studio.js` "Demo deployed: ..." chat-message with a "Demo ready" panel rendering clickable CTAs — kind: frontend | estimate_minutes: 40 (Lulu advises, Soraka implements) <!-- orianna: ok — static/studio.js is company-os/tools/demo-studio-v3/static/studio.js, work-workspace file -->
- [ ] **T.P1.14** — Deploy S3 with `FACTORY_REAL_BUILD=1` to 10 % canary; 24 h soak; promote to 100 % — kind: ops | estimate_minutes: 45 (Ekko)
- [ ] **T.P1.15** — Remove mock fallback + `FACTORY_REAL_BUILD` flag one week post-promotion — kind: code | estimate_minutes: 15 (follow-up, outside P1 ship gate)
- [ ] **T.P1.16** — Akali Playwright QA flow: manual session create → chat → click Build → observe real iPad demo URL → click link → verify loads — kind: qa | estimate_minutes: 40

Total estimate: approx 545 min across 16 tasks. Aphelios re-estimates per strict 60-min cap per task (all current tasks are within the cap).

## Impl surface

Files that will change (full list for Aphelios' breakdown):

**S3 — `company-os/tools/demo-factory/`:** <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- `main.py` — rewrite `_run_build_job` (line 356), extend `build_complete` event payload (line 272-286 of `_run_mock_build` for shape parity) <!-- orianna: ok — company-os/tools/demo-factory/main.py, work-workspace file -->
- `factory_build.py` — NEW, library entry point <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- `config_mgmt_client.py` — NEW, S2 client <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- `tests/test_build.py` — xfail tests T.P1.1, T.P1.7 <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- `tests/test_factory_build.py` — NEW, unit tests for `run_build_from_config` and `s2_config_to_factory_content` <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- `requirements.txt` — no new deps (requests + google-cloud-firestore already present) <!-- orianna: ok — company-os/tools/demo-factory/requirements.txt, work-workspace file -->

**S1 — `company-os/tools/demo-studio-v3/`:** <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- `factory_client_v2.py` — NEW, HTTPS client to S3 <!-- orianna: ok -- work-workspace path, not strawberry-agents -->
- `factory_bridge_v2.py` — rewrite `trigger_factory_v2` (line 17) to call the new client <!-- orianna: ok — company-os/tools/demo-studio-v3/factory_bridge_v2.py, work-workspace file -->
- `main.py` — extend SSE relay to parse build_complete and write session fields; line ~175 `s3_build_sse_stream` and line ~2239 `session_logs_sse` <!-- orianna: ok — company-os/tools/demo-studio-v3/main.py, work-workspace file -->
- `session.py` — extend `_UPDATABLE_FIELDS` allowlist (line 177) <!-- orianna: ok — company-os/tools/demo-studio-v3/session.py, work-workspace file -->
- `static/studio.js` — replace chat-line completion surface (line 860) with panel <!-- orianna: ok — company-os/tools/demo-studio-v3/static/studio.js, work-workspace file -->
- `tests/test_factory_bridge_v2.py` — rewrite for real HTTP client <!-- orianna: ok — company-os/tools/demo-studio-v3/tests/ work-workspace file -->
- `tests/test_build_endpoint.py` — integration test T.P1.12 <!-- orianna: ok — company-os/tools/demo-studio-v3/tests/ work-workspace file -->

**No changes** to `company-os/tools/demo-config-mgmt/` (S2 already exposes `GET /v1/config/{id}`; D3 relies on it). <!-- orianna: ok -- work-workspace path, not strawberry-agents -->

**No changes** to `company-os/tools/demo-factory/factory.py` (kept as CLI for bespoke use). <!-- orianna: ok -- work-workspace path, not strawberry-agents -->

**No changes** to `demo-ui` or `demo-preview` (URL patterns are consumed, not produced).

## Test plan

(Xayah owns. Rakan implements complex-track.)

**Unit:**

- `s2_config_to_factory_content`: 10+ fixtures covering direct-carry, empty, missing-optional, missing-required (raises)
- `factory_client_v2.start_build`: mock httpx, verify URL, method, body shape, Bearer header, timeout; assert no retry on 5xx (non-idempotent)

**Contract (xfail-first per rule 12):**

- T.P1.1 — S3 `POST /build` response shape under `FACTORY_REAL_BUILD=1`
- T.P1.7 — S3 `build_failed` event `reason` values
- S1 `factory_bridge_v2.trigger_factory_v2` persists real `buildId` into session `buildId` field (not synthetic uuid into `factoryRunId`)

**Integration (xfail-first; may require staging WS account; gate pending OQ-3):**

- T.P1.12 — full round-trip with a real staging WS project; shortcode resolves to a `https://demo.missmp.tech/...` that returns 200 when hit

**E2E (Playwright, Akali, per rule 16):**

- User flow: session create → S2 chat → click Build → wait → observe "Demo ready" panel → click "Open iPad demo" → verify opens in new tab with 200 and brand-matching content

**Smoke (post-deploy, per rule 17):**

- stg: POST /build against staging S3 with a canned session; expect real projectId + shortcode within 5 min
- prod: read-only — observe next real user session end-to-end before flipping canary to 100 %

**Fault injection (Xayah/Rakan complex-track):**

- S2 unreachable (`CONFIG_MGMT_URL` wrong) → S3 emits `build_failed / config_fetch_failed` within 10 s
- WS 500 on `create_project` step → S3 retries (existing `WSClient` behaviour) → succeeds, build continues
- WS 500 on `publish_ios_template` final step → S3 emits `build_failed / ws_api_failed`, project remains unpublished; next build with echoed `projectId` resumes
- S1 never receives SSE stream (S3 Cloud Run instance recycled mid-build) → S1 must poll `GET /build/{buildId}` as fallback (already exists, but S1 does not use it today) — OQ-5

## Risks

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | WS API shape drift since `factory.py` was last run against it | med | high | Pre-deploy smoke with a throwaway staging project; pin `WSClient` version via `requirements.txt` | <!-- orianna: ok — factory.py/requirements.txt are company-os/tools/demo-factory/ files, work-workspace -->
| R2 | `s2_config_to_factory_content` translation misses a factory-required field, WS apply step fails cryptically | med | med | Strong defaults + validation in translator (T.P1.4); emit `config_invalid` early with field list |
| R3 | Synchronous `requests` inside asyncio blocks event loop, Cloud Run concurrency drops | low | low | Accept for P1 (one build per session; min-instance CPU headroom); follow-up `asyncio.to_thread` |
| R4 | `FACTORY_TOKEN` absent in the real S3 call path (was only checked for mock) | low | high | xfail test T.P1.1 explicitly asserts `Authorization: Bearer` header present in request; integration test runs against token-guarded endpoint |
| R5 | Shortcode collision on first-rebuild of same session yields `{shortcode}-{project_id}` suffix, changing `demoUrl` silently | med | low | Write the effective shortcode from `get_project` snapshot, not the input; SSE emits the real one; UI shows what S3 reports |
| R6 | SSE stream close before `build_complete` event delivered | low | med | S1 keeps the session doc live (Firestore snapshot picks up status change when S3 writes terminal state); a follow-up `GET /build/{buildId}` fallback is flagged as OQ-5 |
| R7 | Real WS build slower than 10 min for complex templates | low | med | Log step durations; if p95 > 10 min, raise ceiling in a follow-up, not a blocker for P1 |
| R8 | S2 config shape evolves (e.g., new required field added in demo-config-mgmt) without updating translator | med | med | Contract test between S2 response shape and `s2_config_to_factory_content` expected input, pinned in `tests/test_factory_build.py` | <!-- orianna: ok — tests/test_factory_build.py is company-os/tools/demo-factory/tests/ work-workspace file -->

## Grandfathering

This plan targets `orianna_gate_version: 2` as authored. No prior signatures exist (new plan), so the standard Orianna fact-check + approval gate applies at each transition. No bypass anticipated.

## Open questions (OQ) — Duong decisions 2026-04-22

**DECIDED:**
- OQ-1 → **no canary** (internal users, low traffic). Skip traffic-split entirely. Deploy new build code at 100% on first deploy. T.P1.14 simplifies from canary+24h-soak to deploy+smoke.
- OQ-2 → `a` (sync write of buildId/projectId)
- OQ-3 → **`b` full WSClient mock** (no nightly real). CI stays fast and hermetic; real WS drift accepted risk.
- OQ-4 → `a` (defer orphan cleanup)
- OQ-5 → `c` (one-shot GET on SSE close)
- OQ-6 → `a` (env vars for URL hostnames)
- OQ-7 → `b` (Lulu advises, Soraka implements)
- Staging real-build → yes, 100% on first deploy (moot: no canary).

## Open questions (original)

- [x] **OQ-1** — Canary split mechanics: should the 10 % canary be on S3 Cloud Run traffic-split by revision, or a second Cloud Run service (`demo-factory-canary`)?
  - a: same-service traffic-split (cleanest)
  - b: second service with load-balancer fan-out
  - c: env-flag on the existing service, all traffic sees the flag rollout atomic
  - Pick: `a` — existing S3 deploys use revision traffic-split (ops team patterned in `ops/cloud-run/`); avoids a second service lifecycle. <!-- orianna: ok — ops/cloud-run/ is a company-os work-workspace directory, not strawberry-agents -->
- [x] **OQ-2** — Should S1 write `buildId` and `projectId` to the session synchronously (from S3's POST response) or async (wait for first SSE event)?
  - a: sync — `build_session` response already contains them; atomic with status transition (cleanest)
  - b: async — wait for `build_started` event, safer against partial failures
  - c: both — sync write, async overwrite (belt and braces)
  - Pick: `a` — S3 returns them synchronously anyway and the session doc already writes status atomically in the same handler.
- [x] **OQ-3** — Does the integration test T.P1.12 run against a real staging WS account, or a WSClient-level mock?
  - a: real staging (highest fidelity, slow, flaky on WS outages)
  - b: `WSClient` mocked end-to-end (fast, hermetic, doesn't catch real WS regressions)
  - c: real staging only in a nightly scheduled job; PR-time uses mock
  - Pick: `c` — keeps PR CI fast (rule 14) and still catches drift in a daily signal.
- [x] **OQ-4** — Orphan WS projects from abandoned or failed-before-publish builds: clean up in P1 or defer?
  - a: defer; document known leakage (cleanest in scope-fence sense)
  - b: add a daily cleaner Cloud Run Job reading `demo-factory-projects` and archiving via `walletstudio_archive_asset`
  - c: archive on build_failed immediately
  - Pick: `a` — P1 ships the happy path; cleanup is a separate follow-up.
- [x] **OQ-5** — S1 SSE reconnect / fallback if the stream closes before `build_complete` is seen: add `GET /build/{buildId}` polling fallback in P1?
  - a: yes, every 5 s until terminal (robust)
  - b: no, rely on Firestore snapshot (S3 does not write terminal state to Firestore today)
  - c: yes but only as a one-shot check on SSE `close` event
  - Pick: `c` — minimal additional code; covers the single realistic failure mode without polling noise. If Duong picks `b`, add a follow-up task for S3 to write terminal state to Firestore so S1 can read it.
- [x] **OQ-6** — URL hostnames (`app.walletstudio.com`, `demo.missmp.tech`): hardcode in S3 or env-var? <!-- orianna: ok — app.walletstudio.com/demo.missmp.tech are deployed-service hostnames, not filesystem paths -->
  - a: env vars `WS_APP_BASE_URL`, `DEMO_BASE_URL` with prod defaults (cleanest)
  - b: hardcode in `factory_build.py` for MVP, move in follow-up <!-- orianna: ok — factory_build.py is company-os/tools/demo-factory/factory_build.py, work-workspace new file -->
  - c: fetch from a runtime config service
  - Pick: `a` — trivial cost, prevents a stg/prod parity bug.
- [x] **OQ-7** — Lulu advises vs Neeko designs the "Demo ready" panel; which tier?
  - a: Neeko designs (full component spec + mockup), Seraphine implements (complex-track)
  - b: Lulu advises in-session, Soraka implements (normal-track — quicker)
  - c: skip design review, inline with Seraphine from existing studio.css patterns
  - Pick: `b` — a two-line panel with a primary button and a secondary link is within normal-track scope; Neeko is overkill.

## Handoff to Aphelios

Aphelios: this plan locks the **direction** of the P1 ship — MVP path (D1.b), contract (§D2), S3 library extraction (§D3), shortcode→URL resolution (§D4), session state + clickable UI surface (§D5), error taxonomy (§D6), canary rollout (§D7). It stops short of commit-sized work packets.

Your breakdown job:

1. Confirm each §Tasks T.P1.N is 20–60 min (strict 60 cap per the taxonomy rule). T.P1.3 (55 min) is close to the cap — consider splitting into `factory_build.py module skeleton` + `WS-apply step wiring` (~35 + 20). <!-- orianna: ok — factory_build.py is company-os/tools/demo-factory/factory_build.py, work-workspace new file -->
2. Order tasks for TDD discipline (rule 12) — xfail test per contract must land before its implementation. T.P1.1 before T.P1.5; T.P1.7 before T.P1.5 error paths; T.P1.12 before T.P1.8/T.P1.9.
3. Decide concurrency: S3 tasks (T.P1.1–7) and S1 tasks (T.P1.8–11) share only the SSE contract (§D2), so they can parallelize. Viktor on S3, Jayce on S1 is one shape; two Viktors is another (parallelism preference permits).
4. Xayah writes the test plan in full for §Test plan items; Rakan implements the complex-track fault-injection fixtures.
5. Lulu gets OQ-7 (Pick `b`) before Soraka implements T.P1.13.
6. Ekko owns T.P1.14 deploy + 24 h soak; coordinate with Heimerdinger on canary traffic-split mechanics (OQ-1 pick `a`).
7. Akali owns T.P1.16 Playwright QA per rule 16 — this is a new user-flow surface (completion panel with clickable CTAs), so QA report is mandatory in the PR body.

Blockers to surface to Duong via Evelynn before you begin:

- OQ-3 (integration test realism) — pick shapes CI cost
- OQ-5 (SSE fallback) — if Duong picks `b`, a follow-up task on S3 is added
- Whether `FACTORY_REAL_BUILD` canary can run in staging first without flag (recommend yes: staging is single-tenant, flip flag to 100 % on first deploy)

Plan stays at `status: proposed` until Duong approves. No plan-promote.sh run, no signature, no PR. Evelynn dispatches.
