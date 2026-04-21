---
status: approved
orianna_gate_version: 2
concern: work
complexity: normal
tags: [demo-preview, s5, work]
tests_required: true
owner: karma
created: 2026-04-21
---

# S5 demo-preview — add `/fullview` route

## Context

- S5 (`company-os/tools/demo-preview/`) today exposes only `GET /v1/preview/{session_id}` — returns branded HTML tuned for iframe embedding inside S1. Unauthenticated; `Cache-Control: no-cache`; 404 on unknown session via `_fetch_config`. <!-- orianna: ok -->
- The new E2E flow adds a "Open in fullview" button in S1 that opens S5 in a new tab for direct browser navigation. The iframe-sized markup is not well-suited to that use case (needs a proper full-page shell with viewport meta and a visible session header).
- Rendering pipeline (`_fetch_config` + `_render_preview`) is already session-scoped and reusable — the fullview variant only needs a different outer shell.

## Decision

Add a sibling route `GET /v1/preview/{session_id}/fullview` that reuses `_fetch_config` and the same underlying per-session preview content, but wraps it in a full-page HTML document (full `<html>`/`<head>`/`<body>`, viewport meta, minimal header showing brand + session id). Same auth posture (unauthenticated), same `Cache-Control: no-cache`, same 404 semantics on unknown session.

Factor the shared content-rendering into a helper (`_render_preview_body`) so both routes produce identical inner content but different outer shells. Keep the iframe route byte-for-byte backward compatible.

## Phases

One phase. TDD:

1. Add xfail tests covering fullview 200 + content-type + shell markers, and 404 on unknown session.
2. Implement the route + shared body helper; flip tests green.
3. Backward-compat check: existing iframe route test stays green.

## Tasks

1. **Add xfail tests for fullview route** — `kind: test`, `estimate_minutes: 20`
   - Files: `company-os/tools/demo-preview/tests/test_preview.py` (create if missing) <!-- orianna: ok -->
   - Detail: pytest + FastAPI `TestClient`. Cases: (a) `GET /v1/preview/{valid_session}/fullview` → 200, `content-type: text/html`, body contains `<!doctype html`, `<meta name="viewport"`, and `{session_id}`; (b) unknown session → 404; (c) existing `GET /v1/preview/{session_id}` still returns 200 and its current shape. Mark (a) and (b) `@pytest.mark.xfail(strict=True)` referencing this plan slug.
   - DoD: `pytest` runs, xfail tests are xfail (not xpass); commit message includes `xfail: s5-preview-fullview-route`.

2. **Extract shared body renderer** — `kind: refactor`, `estimate_minutes: 15`
   - Files: `company-os/tools/demo-preview/main.py` <!-- orianna: ok -->
   - Detail: split `_render_preview(session_id, config)` into `_render_preview_body(session_id, config)` (inner markup — card/iPad/token sections) and the existing iframe-shell wrapper that calls it. No behavioral change to `/v1/preview/{session_id}`.
   - DoD: iframe-route test still green; no diff in rendered bytes for existing route (snapshot or string equality).

3. **Add `/fullview` route + full-page shell** — `kind: feat`, `estimate_minutes: 25`
   - Files: `company-os/tools/demo-preview/main.py` <!-- orianna: ok -->
   - Detail: new handler `@app.get("/v1/preview/{session_id}/fullview", response_class=HTMLResponse)`. Calls `_fetch_config(session_id)` (404 propagates), then wraps `_render_preview_body(...)` in full `<!doctype html><html><head>...</head><body>...</body></html>` shell with `<meta name="viewport" content="width=device-width, initial-scale=1">`, `<title>{brand} — {session_id}</title>`, minimal header `<header>{brand} preview · session {session_id}</header>`. Response headers: `Cache-Control: no-cache`. Log `"Fullview rendered"` via `_log` with `session_id`.
   - DoD: xfail tests flipped to passing (remove xfail marker in same commit); unit tests green.

4. **Smoke + lint** — `kind: test`, `estimate_minutes: 10`
   - Files: n/a
   - Detail: run full demo-preview test suite + `ruff`/`mypy` per repo config. Manual curl against local uvicorn: `curl -i localhost:8000/v1/preview/demo-001/fullview` → 200 + full shell; unknown id → 404.
   - DoD: suite green; curl output captured in PR body.

## Test plan

Invariants protected:

- **New route returns a full browser-navigation-friendly HTML document** — doctype, `<html>`, viewport meta, `<title>` with session id.
- **Unknown session → 404** — same behavior as iframe route; no info leak difference.
- **Iframe route is unchanged** — byte-equal (or snapshot-equal) output for `/v1/preview/{session_id}` before vs after refactor.
- **No caching** — `Cache-Control: no-cache` present on fullview response.

Tests live in `company-os/tools/demo-preview/tests/test_preview.py`, run under S5's existing pytest config. xfail-first per Rule 12; xfail removal and implementation land in the same commit as the feat. <!-- orianna: ok -->

## Open questions

1. Should the fullview shell include a polling `<meta http-equiv="refresh">` or a client-side `Last-Modified` poll so the tab picks up config edits automatically, or is static-on-load sufficient for v1? (Default assumption: static; Duong can revisit once the E2E flow is live.)
2. Should the minimal header show the brand logo (requires reading `config.brand.logoUrl`) or just a text label? (Default: text label only; logo is a follow-up if Duong asks.) <!-- orianna: ok -->

## Handoff

- **Implementer**: Jayce (normal-track greenfield/additive).
- **Test author**: Vi (xfail scaffold + final green suite).
- **Reviewer**: Senna on PR.
- Plan lives in `plans/proposed/work/`; promote via `scripts/plan-promote.sh` once Orianna signs. <!-- orianna: ok -->
