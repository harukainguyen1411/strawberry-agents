---
status: proposed
orianna_gate_version: 2
complexity: quick
concern: work
owner: karma
created: 2026-04-22
revised: 2026-04-22
target_branch: feat/demo-studio-v3
tags:
  - demo-studio-v3
  - preview
  - bug
  - work
tests_required: true
orianna_signature_approved: "sha256:d1af1ab98ba8ad1bfaa7e8b16ec1e874c4c68069d4fda8b86db75f340e8c8b50:2026-04-22T10:50:18Z"
---

# Preview iframe staleness — port origin/main implementation onto feat branch

> **Revised 2026-04-22 post-Ekko-audit.** The prior H1/H2/H3 triage framing is obsolete. Ekko's audit identified root cause: on the feat/demo-studio-v3 branch, the preview service entrypoint (a 341-LOC FastAPI file named main.py under tools/demo-preview) contains a TODO-stubbed fetch-config that returns hardcoded Allianz regardless of session. Meanwhile the origin/main implementation (a 550-LOC stdlib-http.server + Jinja2 file named server.py under tools/demo-preview) has real Config-Mgmt integration and matches the api-repo OpenAPI spec, but lacks a fullview route and CORS-on-/health added on feat. Duong's decision: canonicalize on origin/main's server.py, port the two missing feat-branch affordances onto it, delete the feat-branch main.py. See `assessments/work/2026-04-22-preview-service-state-audit.md` for full forensics.

## Context

The preview service today exists in two incompatible shapes: a correct-but-incomplete stdlib/Jinja2 implementation on origin/main, and a structurally-newer-but-functionally-broken FastAPI stub on feat/demo-studio-v3. This plan unifies on origin/main's server.py because it (a) has real Config-Mgmt integration — the actual thing that fixes brand staleness, (b) matches the canonical spec at `api/reference/5-preview.yaml` HEAD 4056ac9 using /preview/{session_id} with no /v1/ prefix, <!-- orianna: ok -- api-repo spec path, not in strawberry-agents --> and (c) is simpler — no FastAPI or uvicorn runtime dependency.

Two affordances exist only on feat and must be carried forward: the /preview/{session_id}/fullview route (the second route used by Studio's open-fullview action) and CORS headers on /health (needed for cross-origin probes from the dashboard service). FastAPI is dropped — main's stdlib handler already serves the same surface with fewer moving parts. After the port, Studio's client code must be verified to call /preview/{id}, not /v1/preview/{id} (the feat-only path that dies when main.py is deleted).

A deploy guard goes into the preview deploy script — Ekko's Option B, a branch check via git rev-parse — to prevent the origin/main-from-wrong-checkout accident that produced revision 00009-frw. Zero-cost, git-native, script-level.

## Non-goals

- No redesign of S2 / Config-Mgmt protocol. The port uses the existing Config-Mgmt contract already implemented in server.py.
- No cross-touch with PR #65 (dashboard) or PR #32 (firestore-fix).
- No deploy from this plan. Changes land on feat/demo-studio-v3 only; Duong gates any demo-preview redeploy separately.
- No api-repo spec edit. The port aligns code to the existing spec; no schema change is needed.

## Tasks

### T1 — xfail regression test pinning brand-correctness end-to-end

- kind: test
- estimate_minutes: 25
- files: `mmp/workspace/tools/demo-studio-v3/tests/test_preview_iframe_brand_sync.py` <!-- orianna: ok -- prospective path under work workspace -->
- detail: Playwright-driven test on the work workspace. Step one, POST /session to create a fresh session. Step two, drive chat (or post directly to Config-Mgmt depending on what the test harness exposes) to commit brand equal to Aviva. Step three, load the studio page, wait for settle. Step four, read the preview iframe's resolved URL; fetch it directly and assert the rendered HTML contains Aviva chrome markers and does NOT contain Allianz chrome markers. Mark the test with pytest.mark.xfail and a reason string pointing at this plan file until T4 flips it. Commit lands on the feat branch before any T2/T3/T4 fix commit per Rule 12.
- DoD: test runs red-xfail locally; pytest on that single test file exits green because xfail counts as expected; committed with a `test(demo-preview):` prefix.

### T2 — Port origin/main server.py onto feat branch; delete feat main.py

- kind: refactor
- estimate_minutes: 35
- files: `tools/demo-preview/server.py` <!-- orianna: ok -- work workspace path, ported from origin/main --> plus the templates, static, and configs directories under `tools/demo-preview` <!-- orianna: ok -- work workspace directory -->, `tools/demo-preview/requirements.txt` <!-- orianna: ok -- work workspace path -->, `tools/demo-preview/Dockerfile` <!-- orianna: ok -- work workspace path -->, `tools/demo-preview/main.py` <!-- orianna: ok -- to be deleted from feat branch --> (deleted)
- detail: On the feat branch in the work workspace, run git checkout origin/main to pull server.py, templates, static, and configs into the working tree — mechanical port, no logic changes. Then four sub-steps. Sub-step-alpha, rm the feat branch's main.py. Sub-step-beta, update requirements.txt to drop fastapi, uvicorn, requests; keep jinja2 only; server.py uses stdlib urllib.request for the Config-Mgmt HTTP call. Sub-step-gamma, update the Dockerfile CMD to invoke server.py instead of main.py — confirm main's Dockerfile is already correct for server.py and cherry-pick it if so. Sub-step-delta, preserve the feat branch's deploy.sh — it has the correct Secret Manager names DS_PREVIEW_TOKEN and DS_CONFIG_MGMT_TOKEN per Ekko Q3. Commit with a `refactor(demo-preview):` prefix.
- DoD: running server.py locally against live or stubbed Config-Mgmt serves GET /preview/{session_id}; main.py is gone from the tree; requirements.txt has no FastAPI dependency; diff is a mechanical port with no invented logic.

### T3 — Port fullview route and CORS-on-/health from feat onto server.py

- kind: feat
- estimate_minutes: 30
- files: `tools/demo-preview/server.py` <!-- orianna: ok -- work workspace -->, `tools/demo-preview/templates/preview_fullview.html` <!-- orianna: ok -- prospective if not already present on main -->
- detail: Two additive changes to the ported server.py. First, add GET /preview/{session_id}/fullview — same Config-Mgmt fetch and Jinja2 render path as /preview/{session_id}, but using the fullview template variant, setting Cache-Control no-cache, and omitting X-Frame-Options, per api-repo spec. Reference the feat branch's main.py render-preview-body function for the fullview body shape; translate its inline CSS into a Jinja2 template at templates/preview_fullview.html if main does not already have one, otherwise reuse main's existing template. Second, add CORS headers to the /health response — Access-Control-Allow-Origin star, Access-Control-Allow-Methods GET and OPTIONS, and handle OPTIONS /health returning 204 with the same headers. Leave the rest of server.py untouched. Commit with a `feat(demo-preview):` prefix.
- DoD: curl against localhost /preview/{id}/fullview returns 200 with Cache-Control no-cache and no X-Frame-Options; curl OPTIONS /health returns 204 with CORS headers; curl GET /health returns 200 with Access-Control-Allow-Origin set; both routes match api-repo spec shapes.

### T4 — Studio.js URL verification; flip xfail; deploy guard

- kind: fix
- estimate_minutes: 25
- files: `mmp/workspace/tools/demo-studio-v3/static/studio.js` <!-- orianna: ok -- work workspace -->, `tools/demo-preview/deploy.sh` <!-- orianna: ok -- work workspace -->, `mmp/workspace/tools/demo-studio-v3/tests/test_preview_iframe_brand_sync.py` <!-- orianna: ok -- prospective, created by T1 -->
- detail: Three sub-steps. Sub-step-one, grep studio.js for the string slash-v1-slash-preview; if any hit, replace with slash-preview to match server.py's spec-aligned routes. Also check that the fullview URL construction uses /preview/{id}/fullview and not /v1/preview/{id}/fullview. Sub-step-two, add to the top of deploy.sh — after the shebang and set-euo-pipefail — a check that git rev-parse abbrev-ref HEAD equals feat/demo-studio-v3, else echo an error and exit 1. Per Ekko Option B: zero new files, git-native. Sub-step-three, remove the xfail marker from T1's test; run pytest and confirm green; also run a second assertion swapping Aviva for Lemonade to prove it is not anything-but-Allianz. Save a Playwright screenshot to `assessments/qa-reports/2026-04-22-preview-iframe-staleness-live.png` <!-- orianna: ok -- prospective screenshot under strawberry-agents -->. Commit with a `fix(demo-preview):` prefix.
- DoD: studio.js calls /preview/{id} and /preview/{id}/fullview with no /v1/ prefix anywhere; deploy.sh refuses to run from main or any non-feat branch; xfail is removed and pytest is green; screenshot attached.

## Test plan

Invariants protected, all exercised by the T1/T4 regression test plus a small T3 smoke:

- Inv-PREVIEW-1: given a session bound to brand B, GET /preview/{session_id} returns HTML containing brand B chrome and no other brand chrome. Protected by the T1/T4 regression test; underpinned by server.py's real Config-Mgmt integration — the thing the feat branch's main.py lacked.
- Inv-PREVIEW-2: GET /preview/{session_id}/fullview returns HTML with Cache-Control no-cache and without X-Frame-Options, per api-repo spec. Protected by a direct-fetch assertion added to the regression test in T4.
- Inv-PREVIEW-3: OPTIONS /health returns 204 with CORS headers; GET /health returns 200 with Access-Control-Allow-Origin set. Protected by a curl-style assertion in T3's smoke and re-asserted in T4.
- Inv-DEPLOY-GUARD: the preview deploy.sh exits non-zero when run from any branch other than feat/demo-studio-v3. Protected by a trivial shell assertion in T4 — create a throwaway branch, invoke deploy.sh, assert exit 1, delete the branch.

Per Rule 12: T1 lands xfail on the feat branch before T2/T3/T4 fix commits. Per Rule 13: this is a bug fix; T1 plus T4 together satisfy the regression-test requirement on the same branch as the fix.

## Key decisions

- FastAPI versus stdlib — pick stdlib. The ported server.py uses stdlib http.server plus urllib.request plus jinja2. Dropping FastAPI removes three runtime dependencies with no functional loss. Simpler, fewer moving parts, smaller cold-start on Cloud Run. The FastAPI version was introduced on feat without a forcing requirement.
- Route shape — align to api-repo spec, no /v1/ prefix. The spec is canonical and uses /preview/{session_id}. server.py already matches; studio.js must follow.
- Deploy guard — Option B only. Ekko recommended B plus a partial A (a docs file). Skip A for this slice — the branch check in deploy.sh is the load-bearing guard; a separate DEPLOY-NOTE doc is pure docs and can land later if needed. Keeps the diff minimal.

## Risks

- server.py's Config-Mgmt integration may have evolved on the feat branch via intermediate commits not yet landed on main — auth header shape, retry behavior. Mitigation: T2 is a straight cherry-pick; if T3 local smoke shows 401 or 5xx from Config-Mgmt, patch the auth header on server.py to match what feat's main.py was sending before deletion — as a follow-up task, not in-band with T2.
- server.py's Dockerfile may diverge from what Cloud Run build expects with the feat branch's deploy.sh. Mitigation: T2 cherry-picks the Dockerfile from main alongside server.py; T4's deploy-guard branch check is the only deploy.sh change.
- Playwright flakiness on iframe cross-origin reads. Mitigation: assert on the iframe src URL plus a direct HTTP fetch, not on iframe document DOM traversal.

## References

- `assessments/work/2026-04-22-preview-service-state-audit.md` — Ekko's full forensics; origin/main is 013a15e, feat HEAD is 0bb60d8, live revision is 00009-frw.
- api-repo spec at api/reference/5-preview.yaml HEAD 4056ac9.
- Sibling plans on the feat branch live under plans/proposed/work in this repo.
