# PR #65 — demo-dashboard W1 scaffold review

**Date:** 2026-04-22
**Repo:** missmp/company-os
**PR:** #65 feat/demo-dashboard-split → main
**Verdict:** ADVISORY LGTM (comment under duongntd99; reviewer lane still ungated on missmp/*)
**Review URL:** https://github.com/missmp/company-os/pull/65#issuecomment-4295059625

## What it was

W1 scaffold for the dashboard-split ADR. 127/0 diff, 8 new files all under `tools/demo-dashboard/**`:
- `main.py` (25 lines): FastAPI app with `/healthz` only + empty lifespan stub
- `Dockerfile`: python:3.12-slim single-stage, port 8090
- `deploy.sh`: Cloud Run deploy with dry-run flag, required-env guards, SCRIPT_DIR via BASH_SOURCE
- `requirements.txt`: fastapi/uvicorn/firestore/httpx/itsdangerous/jinja2/pillow (unbounded)
- `secrets-mapping.txt`: SESSION_SECRET + INTERNAL_SECRET references only (names, no values)
- `tests/test_health.py` + `conftest.py`: TestClient + sys.path shim

Rule-12 chain clean: a72d64e xfail → fede8ac scaffold → cb57ce6 xfail-flip.

## Findings

**None critical, none important.** 7 non-blocking suggestions all W5-gated:
1. requirements.txt no upper bounds (sibling uses `<Y`)
2. Dockerfile hardcodes --port 8090, ignores Cloud Run $PORT
3. deploy.sh git mode 100644 (not +x)
4. Dry-run heredoc escapes $SCRIPT_DIR — not copy-paste runnable
5. Stale dev note in conftest.py referencing Viktor "once W1 scaffold lands" (has landed)
6. No .dockerignore — COPY . . ships tests/ and deploy.sh into image
7. Unused lifespan(application) param — pylint nit

## Patterns reinforced

1. **For fresh-service skeleton PRs, focus security review on:** (a) only-claimed endpoints actually exist, (b) secrets files contain names not values, (c) auth posture is closed-by-default pending later waves, (d) deploy.sh doesn't leak env vars. All four passed clean here.

2. **Compare against sibling service under same repo's `tools/`.** When repo has multiple deployable services, diff the new one against the closest sibling (here: `demo-studio-config-mgmt`) for style/idiom drift. Findings 1 (upper-bound version pin) and 2 (hardcoded Docker port) both came from that comparison.

3. **The "$PORT ignored" pattern on Cloud Run Python containers** — Cloud Run injects `PORT` env var at runtime; a Dockerfile that hardcodes `--port N` in CMD silently ignores it. Works only because the deploy config explicitly pins container-port to match. Sibling services in this repo do the same, so it's idiomatic not novel — but flag as a latent gotcha for any service that might migrate to the default container-port=8080.

4. **deploy.sh heredoc escape hygiene for dry-run.** The pattern `\${SCRIPT_DIR}` inside an unquoted heredoc prints literal `${SCRIPT_DIR}` — useful if the dry-run is meant to show "what the script will substitute", but hostile to copy-paste users who want "the exact command that will run". Flag as minor UX nit, never blocking.

5. **Reviewer-lane gap on missmp/ remains (S27 through S36).** `strawberry-reviewers-2` still can't see missmp/* repos. Default `gh` falls back to `duongntd99` which is usually the PR author too — formal APPROVED/CHANGES_REQUESTED unavailable, must use `--comment` advisory. Continue flagging to Sona. This has persisted ~5 sessions now — worth prioritizing.

6. **For W1-style "scaffold-only" PRs, verify the test actually exercises the claimed endpoint.** Here `test_healthz_returns_200` uses `TestClient(app).get("/healthz")` + `status_code == 200` — reverting the `@app.get("/healthz")` decorator would flip it red. NOT a tautology (e.g., an `assert True` would pass regardless). Ran locally to confirm: `1 passed in 0.19s`.

## Positives to remember for future scaffold reviews
- `: "${VAR:?msg}"` bash idiom for required-env guards is the right pattern (vs `[ -z ... ]` checks).
- `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` is the portable repo-root anchor.
- Lifespan context manager (rather than deprecated `@app.on_event`) is the modern FastAPI pattern.
- `secrets-mapping.txt` as a names-only env=secret:version file is a clean separation vs baking names into deploy.sh.
