# Loop 1 QA — Dashboard service-health CORS proxy verified green

**Date:** 2026-04-22
**Branch / HEAD:** `feat/demo-studio-v3` @ `9b812ce` (fix commit)
**Predecessor xfail commit:** `2834bc5`
**Plan:** `plans/proposed/work/2026-04-22-dashboard-service-health-cors-proxy.md`
**Surface:** local — S1 at `http://127.0.0.1:8080/dashboard`

## Before (identify pass)

- Dashboard opened at 2026-04-22T06:21:48Z.
- 33 CORS errors in console across 3 poll cycles × 4 services.
- S2 / S3 / S4 / S5 health cards all DOWN, "Failed to fetch".
- Example error:
  > Access to fetch at `https://demo-config-mgmt-4nvufhmjiq-ew.a.run.app/health`
  > from origin `http://127.0.0.1:8080` blocked by CORS policy.
  > `Access-Control-Allow-Origin: https://demo-studio-266692422014.europe-west1.run.app`
  > is not equal to the supplied origin.
- Root cause: dashboard.html fetched Cloud Run URLs client-side; S2–S5 CORS was
  configured to a single hardcoded prod origin that excludes localhost and any
  alternate demo-studio origin.

## Change

- **Plan:** `strawberry-agents plans/proposed/work/2026-04-22-dashboard-service-
  health-cors-proxy.md` committed to main as `34b0641`.
- **xfail test:** `tools/demo-studio-v3/tests/test_service_health_proxy.py`
  committed on `feat/demo-studio-v3` as `2834bc5` (9 xfails).
- **Fix:** `tools/demo-studio-v3/main.py` — added
  `GET /api/service-health/{name}/health` server-side proxy + swapped
  `/dashboard` handler's `service_urls` to inject relative proxy paths for
  S2–S5. S1 unchanged. Test xfail markers flipped off; all 9 tests green.
  Committed on `feat/demo-studio-v3` as `9b812ce`.

## After (verify pass)

- Dashboard reopened at 2026-04-22T06:43:11Z, after uvicorn reload.
- `window.__serviceUrls` (verified via page.evaluate):
  ```json
  {
    "s1Base": "http://localhost:8080",
    "configMgmt": "/api/service-health/s2",
    "factory": "/api/service-health/s3",
    "verification": "/api/service-health/s4",
    "preview": "/api/service-health/s5"
  }
  ```
- All 5 health cards report **UP**:
  - S1 Demo Studio UP 74 ms
  - S2 Config Mgmt UP 481 ms
  - S3 Factory UP 506 ms
  - S4 Verification UP 480 ms
  - S5 Preview UP 482 ms
- Console errors: **1 total**, all from `/favicon.ico` 404 (cosmetic, unrelated).
- **Zero CORS errors.** Down from 33 in 3 cycles (pre-fix) to 0 per cycle (post-fix).
- Direct curls against `/api/service-health/{s2..s5}/health` all return `{"status":"ok"}` HTTP 200.

## Tests

```
tests/test_service_health_proxy.py::test_proxy_returns_upstream_body_on_success[s2-CONFIG_MGMT_URL] PASSED
tests/test_service_health_proxy.py::test_proxy_returns_upstream_body_on_success[s3-FACTORY_URL] PASSED
tests/test_service_health_proxy.py::test_proxy_returns_upstream_body_on_success[s4-VERIFICATION_URL] PASSED
tests/test_service_health_proxy.py::test_proxy_returns_upstream_body_on_success[s5-PREVIEW_URL] PASSED
tests/test_service_health_proxy.py::test_proxy_unknown_service_returns_404 PASSED
tests/test_service_health_proxy.py::test_proxy_upstream_unconfigured_returns_503 PASSED
tests/test_service_health_proxy.py::test_proxy_upstream_error_returns_502 PASSED
tests/test_service_health_proxy.py::test_proxy_preserves_upstream_non_200_status PASSED
tests/test_service_health_proxy.py::test_dashboard_injects_same_origin_proxy_paths_for_s2_s5 PASSED
9 passed in 0.86s
```

## Screenshot

`assessments/qa-reports/2026-04-22-loop1-cors-proxy-dashboard-all-5-up.png`

Shows all 5 cards UP with green indicators, sessions sidebar populated, no
DOWN badges.

## Follow-ups not taken this loop

- S2–S5 native CORS allowlist (superseded by the proxy for this surface;
  filed as "out of scope" in the plan).
- Favicon 404 (cosmetic, deferred).
- The pre-existing `list fetch failed` badge on a secondary panel was **not**
  investigated this loop — remains under P5 Dashboard thread for next loop.
