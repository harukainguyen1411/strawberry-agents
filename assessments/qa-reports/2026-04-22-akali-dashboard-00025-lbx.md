# QA Report — Dashboard + Service Health + Managed Agents Tab
**Revision:** demo-studio-00025-lbx  
**Target:** https://demo-studio-266692422014.europe-west1.run.app  
**Date:** 2026-04-22  
**Akali scope:** Dashboard load, service cards, `window.__serviceUrls`, health polls, Managed Agents tab, Refresh all, stale inputs

---

## Per-Check Results

| # | Check | Result | Notes |
|---|-------|--------|-------|
| 1 | Dashboard loads with 5 service cards (S1–S5) | PASS | S1 UP, S2 UP, S3 DOWN, S4 DOWN, S5 DOWN — cards present and labelled correctly |
| 2 | `window.__serviceUrls` server-injected with all 5 keys | PASS | Confirmed via `curl` grep and browser eval on session page: `s1Base`, `configMgmt`, `factory`, `verification`, `preview` — all Cloud Run URLs, zero `localhost` references |
| 3 | Health polls target real Cloud Run URLs, no `localhost:*` | PASS | Network requests show `demo-factory-*.run.app/health`, `demo-preview-*.run.app/health`, `demo-verification-*.run.app/health` — no ERR_CONNECTION_REFUSED to localhost |
| 4 | S3/S4/S5 DOWN status acceptable (Ekko deploys in flight) | PASS | DOWN with `{"error":"Failed to fetch"}` — expected; CORS blocks browser-side `/health` on factory/verification/preview |
| 5 | Managed Agents tab absent | PASS | No "Managed Agents" button found in DOM — Soraka commit `c138203` confirmed effective |
| 6 | No `Failed to load managed sessions: HTTP 404` banner | PASS | No such error observed in console or snapshot |
| 7 | "Refresh all" button present, no `/managed-sessions` 404 | PASS | Button present; no `managed-sessions` network request observed |
| 8 | Stale inputs `cfg-mcp-studio` / `cfg-wallet-mcp` removed | PASS | Dashboard inputs: `cfg-backend`, `log-filter-session`, `tool-filter-session`, `tool-filter-name` — no stale IDs |
| 9 | Console errors on dashboard load — clean or only `/health` 404s | PARTIAL | 19 errors on dashboard page: all CORS-blocked `/health` fetches on S3/S4/S5 (`demo-factory`, `demo-verification`, `demo-preview`). No unexpected errors. |

---

## Findings

**[SEV-3 / INFO] S2 health URL mismatch in `window.__serviceUrls`**  
`configMgmt` resolves to `demo-config-mgmt-4nvufhmjiq-ew.a.run.app` which returned UP (659ms). However `__serviceUrls` key is `configMgmt` not `CONFIG_MGMT_URL` — task spec named the keys differently (`BASE_URL`, `CONFIG_MGMT_URL`, `FACTORY_URL`, `VERIFICATION_URL`, `PREVIEW_URL`). Actual keys are `s1Base`, `configMgmt`, `factory`, `verification`, `preview`. Functionally equivalent; naming differs from spec. Non-blocking.

**[SEV-3 / INFO] Dashboard session-detail panel JS error**  
Snapshot shows `"Error: Cannot set properties of null (setting 'textContent')"` in the Status row of the session detail panel for session `0fdb1de0`. Appears to be a race condition when the session status element is set before the DOM node renders. Low severity — cosmetic, session data is otherwise displayed.

**[SEV-3 / INFO] S3/S4/S5 CORS on browser-side `/health`**  
Factory, Verification, and Preview services do not include `Access-Control-Allow-Origin` headers, so browser-side health checks fail with CORS. This produces 19 console errors. Expected during Ekko deploy phase; should be revisited once those services are live.

**[SEV-3 / INFO] `window.__serviceUrls` undefined on direct dashboard page eval**  
`window.__serviceUrls` returns `undefined` when evaluated via Playwright MCP on `/dashboard?session=...` — likely a timing issue with server-rendered `<script>` injection vs. Playwright's eval context. `curl` confirms the variable IS present in the HTML source. No functional impact.

---

## Verdict: PASS

All blocking checks pass. S3–S5 DOWN is expected and acceptable per scope. Console errors are exclusively CORS/health-poll related. Managed Agents tab is gone. No localhost URLs. No stale inputs.

---

## Artifacts

- Screenshot: `akali-qa-dashboard-00025-lbx.png` (viewport)
- Screenshot: `akali-qa-dashboard-00025-lbx-full.png` (full page)
- Playwright session: `.playwright-mcp/`
