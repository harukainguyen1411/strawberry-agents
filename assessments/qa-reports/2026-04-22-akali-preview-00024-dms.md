# QA Report — Preview Iframe | demo-studio-00024-dms

**Date:** 2026-04-22
**Revision:** demo-studio-00024-dms (https://demo-studio-266692422014.europe-west1.run.app)
**Session used:** fdb839ec49234fef8b747559161fb145
**Soraka commits verified:** 0b3947d (F-C1 s5Base), 817a638 (F-C5 sandbox), 2938c6a (T.GAP.1b session.html)
**Scope:** Preview iframe only (non-overlapping with other scoped Akalis)

---

## Per-Screen Results

| # | Check | Result | Notes |
|---|-------|--------|-------|
| 1 | `window.__s5Base` defined on session page | PASS | `https://demo-preview-4nvufhmjiq-ew.a.run.app` — PREVIEW_URL fallback working (0b3947d) |
| 2 | iframe `src` uses `{__s5Base}/v1/preview/{sid}` — no placeholder | PASS | Confirmed: `https://demo-preview-4nvufhmjiq-ew.a.run.app/v1/preview/fdb839ec49234fef8b747559161fb145` |
| 3 | iframe renders content (not "S5_BASE not configured" placeholder) | PASS | S5 service returned branded pass card (Allianz / Motor Insurance); empty-state hidden |
| 4 | BUG-A3 auto-nav to `/session/{sid}/preview` absent | PASS | Page held `…/session/fdb839ec49234fef8b747559161fb145` for 3 s with no redirect |
| 5 | Sandbox lacks `allow-same-origin`; no sandbox console warning | PASS | `sandbox="allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox"` — no warnings (817a638) |
| 6 | "Open full screen" opens new tab pointing at S5 fullview URL | PASS | New tab opened at `https://demo-preview-4nvufhmjiq-ew.a.run.app/v1/preview/{sid}/fullview` |

---

## Observations (out-of-scope, FYI only)

- **INFO:** An "Open in fullview" link also appears in the toolbar alongside "Open full screen" — both point to the S5 fullview URL. Likely intentional but may be redundant UI.
- **INFO:** Dashboard health probes to `localhost:3100` and `localhost:3001` generate console errors on the dashboard page; not present on the session page and out of scope for this Akali.

## Screenshot

Path: `akali-qa-session-page-00024.png` (saved to repo root during Playwright run)

## Verdict

**PASS** — All 6 preview-iframe checks green. Soraka fixes 0b3947d and 817a638 are confirmed effective on the live 00024-dms revision.
