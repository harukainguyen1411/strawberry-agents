---
status: proposed
orianna_gate_version: 2
complexity: normal
concern: work
owner: sona
created: 2026-04-22
tags:
  - demo-studio
  - dashboard
  - cors
  - bugfix
  - work
tests_required: true
---

# Loop 1 — Dashboard service health cards blocked by CORS

<!-- orianna: ok — every file-path token in this plan (main.py, dashboard.html, tests/test_service_health_proxy.py, tools/demo-studio-v3/*) references files inside the missmp/company-os work workspace under company-os/tools/demo-studio-v3/, not strawberry-agents local files -->
<!-- orianna: ok — HTTP path tokens (/api/service-health/{name}/health, /dashboard, /health) are route paths on the demo-studio Cloud Run service, not filesystem paths -->
<!-- orianna: ok — env-var name tokens (BASE_URL, CONFIG_MGMT_URL, FACTORY_URL, VERIFICATION_URL, PREVIEW_URL) are Cloud Run env vars, not filesystem paths -->
<!-- orianna: ok — literal placeholders (<upstream>/health, <ENV_URL>/health, <url>, <path>, {name}) are illustrative URL templates, not filesystem paths -->
<!-- orianna: ok — config.backend is a JS variable reference inside dashboard.html, not a filesystem path -->

## 1. Context

`/dashboard` on S1 renders five service-health cards (S1 Demo Studio, S2
Config Mgmt, S3 Factory, S4 Verification, S5 Preview). Client-side JS in
`dashboard.html` <!-- orianna: ok --> (around line 903 `SERVICES = [...]`) polls each
service's `/health` by calling `fetch(<url> + <path>)`. <!-- orianna: ok --> The
URLs come from the server injection `window.__serviceUrls` emitted by the
`/dashboard` handler in `main.py` <!-- orianna: ok --> (~line 759):

    service_urls = {
        "s1Base": os.getenv("BASE_URL", ""),
        "configMgmt": os.getenv("CONFIG_MGMT_URL", ""),
        "factory": os.getenv("FACTORY_URL", ""),
        "verification": os.getenv("VERIFICATION_URL", ""),
        "preview": os.getenv("PREVIEW_URL", ""),
    }

S2–S5 on Cloud Run respond with
`Access-Control-Allow-Origin: https://demo-studio-266692422014.europe-west1.run.app`
— a single hardcoded origin. Any other caller (`http://127.0.0.1:8080` local
dev, or any alternate prod origin) is blocked by CORS. Dashboard shows S2–S5
as **DOWN / "Failed to fetch"** even when upstream is healthy.

Evidence captured in Playwright console log 2026-04-22T06:21:48 (33 CORS errors,
one per service × three poll cycles).

## 2. Decision

Add a same-origin proxy route on S1 that dashboard HTML calls instead of the
absolute Cloud Run URLs. Server-side httpx fetches the upstream `/health`, echoes
body + status. Browser only ever makes same-origin requests. No S2–S5 redeploy
required; future CORS config on those services becomes moot for this surface.

    GET /api/service-health/{name}/health       (name ∈ {s2, s3, s4, s5})
        → httpx.get("<ENV_URL>/health")
        → return upstream status + body verbatim

`window.__serviceUrls.{configMgmt,factory,verification,preview}` now emits
relative proxy paths (`/api/service-health/s2`, …) instead of Cloud Run URLs.
`s1Base` is unchanged — S1 checks its own co-located `/health`, no CORS.

Failure modes mapped explicitly:

| Condition                        | Proxy status | Body                                    |
|----------------------------------|--------------|-----------------------------------------|
| Unknown service name             | 404          | `{"detail": "unknown service"}`         |
| Env URL unset / empty            | 503          | `{"detail": "upstream not configured"}` |
| Network / TLS / timeout failure  | 502          | `{"detail": "upstream error: <class>"}` |
| Upstream non-2xx                 | passthrough  | upstream body verbatim                  |
| Upstream 2xx                     | passthrough  | upstream body verbatim                  |

## 3. Scope

- **In scope:** S2, S3, S4, S5 `/health` polling from `/dashboard`.
- **Out of scope:** any other cross-origin call from dashboard (session list,
  managed-sessions — those already hit `config.backend` <!-- orianna: ok --> which
  is same-origin by default); S5 preview iframe (that renders directly from
  the Cloud Run origin, which is intended — not a fetch).

## Test plan

Test file: `tools/demo-studio-v3/tests/test_service_health_proxy.py`
<!-- orianna: ok -->. Committed as xfail-first (Rule 12 TDD gate), markers
flipped off once route lands.

Cases:

1. 2xx upstream → proxy 2xx with upstream body echoed (parametrized over s2/s3/s4/s5).
2. Unknown service name → 404 with `"unknown service"` in detail.
3. Unconfigured env URL → 503 with `"not configured"` detail.
4. Upstream raises → 502 with error-class name.
5. Upstream 503 → proxy 503, body echoed verbatim.
6. `/dashboard` HTML injects `/api/service-health/{s2..s5}` for S2–S5; `s1Base`
   unchanged.

Committed xfail → flip green after route lands.

## 5. Risks

- httpx already imported in `main.py` <!-- orianna: ok --> (lines 185, 248) —
  no new dep.
- Proxy is cached by nothing; each poll hits upstream. Poll cadence is 30s
  (`dashboard.html` <!-- orianna: ok --> `pollHealth`), so ~4 calls / 30s per
  dashboard. Acceptable.
- Adds one round-trip of latency vs direct call. Acceptable for a health poll.

## 6. Out of scope follow-ups

- Fix S2–S5 CORS config at the source (proper regex allowlist) — nice-to-have
  but moot after this proxy; file as low-priority cleanup if ever re-raised.
- Batch endpoint `/api/service-health` returning all four — keep per-service
  for symmetry with S1 polling pattern.

## Tasks

- [ ] **T.1** — Write xfail test file `tools/demo-studio-v3/tests/test_service_health_proxy.py` covering the six cases in §Test plan. owner: sona. estimate_minutes: 10. Files: `tools/demo-studio-v3/tests/test_service_health_proxy.py` <!-- orianna: ok -->. DoD: `pytest tests/test_service_health_proxy.py -q` reports 9 xfailed, 0 xpassed.
- [ ] **T.2** — Implement proxy route `GET /api/service-health/{name}/health` in `main.py` using the already-imported `httpx`; swap the `/dashboard` handler's `service_urls` dict so S2–S5 emit relative proxy paths, S1 unchanged. owner: sona. estimate_minutes: 15. Files: `tools/demo-studio-v3/main.py` <!-- orianna: ok -->. DoD: route returns per §2 table; uvicorn reload clean; all xfail markers flipped off and tests green.
- [ ] **T.3** — Verify live via Playwright against `http://127.0.0.1:8080/dashboard` — dashboard shows S2–S5 as UP (or upstream's actual status) with no CORS errors in console. owner: sona. estimate_minutes: 5. Files: (runtime-only, no file edits). DoD: screenshot captured under `assessments/qa-reports/`; console has 0 CORS errors; service-health cards render.

## Architecture impact

- `main.py` <!-- orianna: ok --> — one new route
  `/api/service-health/{name}/health`, plus edits to the `/dashboard`
  handler's `service_urls` dict.
- `tools/demo-studio-v3/tests/test_service_health_proxy.py` <!-- orianna: ok -->
  — new file.
- `dashboard.html` <!-- orianna: ok --> — **unchanged**; `SERVICES[].url +
  SERVICES[].path` still resolves correctly because injected url =
  `/api/service-health/s2`, path = `/health`, full URL =
  `/api/service-health/s2/health` (matches the new route).

## Loop context

First loop of Duong's "hands-dirty e2e fix" cadence (Playwright identify →
plan+test → fix → Playwright verify → pause+compact → next loop). Does not
gate the Firebase-auth work
(`plans/approved/work/2026-04-22-firebase-auth-for-demo-studio.md`
<!-- orianna: ok -->), which is Loop 2.
