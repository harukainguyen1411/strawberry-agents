---
date: 2026-04-27
created: 2026-04-27
concern: work
status: proposed
author: karma
owner: karma
complexity: quick
tier: quick
orianna_gate_version: 2
tests_required: true
qa_co_author: senna
qa_plan: required
ui_involvement: no
priority: P1
last_reviewed: 2026-04-27
UX-Waiver: server-side endpoint — no UI surface
---

# Wire `/v1/schema` at S2 to the canonical `schema.yaml`

## Context

`GET /v1/schema` on the demo-config-mgmt service (S2) returns an 11-field
`MOCK_SCHEMA_YAML` stub that documents only `brand`, `market`, `languages`,
`shortcode`, `colors.{primary,secondary,background,foreground,label}`, and
`logos.{wideLogo,squareLogo}`. The canonical schema lives at
`tools/demo-studio-schema/schema.yaml` (524 lines) and covers ~14 top-level
keys including `card.front[]`, `card.back`, `card.cta`, `params`, `ipadDemo`,
`journey`, and `tokenUi`. The TODO at
`tools/demo-config-mgmt/main.py:117` and the duplicate TODO at
`main.py:186` both flag this gap explicitly.

The user-visible symptom (session `e352044b37c04e828c7524c7034fdb75`): the
agent fetches `/v1/schema`, believes the contract is 11 fields, writes a
minimal config, then calls `get_config` and sees ~100 fields populated from
`DEFAULT_SEED` (`MOCK_CONFIG` at `main.py:205`, which has the full shape).
Mismatch reads as "my write was overwritten" and the agent gaslights itself.
Wiring the response to the real `schema.yaml` makes the contract the agent
sees match the contract the iframe and OpenAPI spec already use.

This plan is independent of and must not be bundled with
`plans/proposed/work/2026-04-27-adr-4-set-config-validation-framing.md`
(set_config dispatch traceability) or the S2 in-memory single-instance
fragility. Single PR, scoped strictly to `tools/demo-config-mgmt/`.

## Decision

- **D1 — bundle `schema.yaml` into the image.** The `Dockerfile` copies the
  build context (`tools/demo-config-mgmt/`) only; the schema lives in a
  sibling tool dir. Bundling means copying `schema.yaml` into the image at
  build time. Two acceptable shapes (executor picks):
  (a) extend `Dockerfile` build context to the parent (`tools/`) and `COPY
  demo-studio-schema/schema.yaml ./schema.yaml`, adjusting `deploy.sh`
  build context accordingly; or
  (b) keep build context as-is and have `deploy.sh` `cp` the schema into
  the build dir before `gcloud run deploy`, with the file gitignored if
  copied locally. Prefer (a) — it keeps the source of truth canonical and
  removes the `cp` side-effect from `deploy.sh`. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
- **D2 — read schema at cold start, cache in module scope.** Read once
  with `pathlib.Path(__file__).parent / "schema.yaml"`. Validate it parses
  as YAML at import time (fail fast if the bundled file is corrupt). Serve
  the raw text on every request — the wire format stays YAML.
- **D3 — delete `MOCK_SCHEMA_YAML` and both TODOs.** No fallback. If the
  file is missing the service should fail to start, not silently serve a
  stub.

## Anchors

- `tools/demo-config-mgmt/main.py:114-157` — `MOCK_SCHEMA_YAML` constant to delete. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
- `tools/demo-config-mgmt/main.py:182-187` — `get_schema` handler to rewire. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
- `tools/demo-config-mgmt/Dockerfile` — extend build context / `COPY` schema. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
- `tools/demo-config-mgmt/deploy.sh` — adjust `gcloud run deploy --source` context if D1(a). <!-- orianna: ok -- cross-repo path in missmp/company-os -->
- `tools/demo-studio-schema/schema.yaml` — canonical source (read-only here). <!-- orianna: ok -- cross-repo path in missmp/company-os -->
- `tools/demo-config-mgmt/tests/integration/` — new test file lands here. <!-- orianna: ok -- cross-repo path in missmp/company-os -->

## Tasks

1. **TX1 — xfail test: `/v1/schema` returns the canonical full schema.**
   Add an integration test that:
   (a) GETs `/v1/schema` with a valid auth header,
   (b) parses the response body as YAML,
   (c) asserts the parsed dict contains every top-level key present in
   `tools/demo-studio-schema/schema.yaml` (load the canonical file in the
   test, walk its top-level keys, assert each is in the response),
   (d) asserts the response contains at least the seven top-level keys
   absent from the old stub: `card`, `params`, `ipadDemo`, `journey`,
   `tokenUi` plus the JSON-Schema markers `$schema` and `$id`,
   (e) asserts the response body is byte-equivalent to the bundled
   `schema.yaml` (snapshot test against the canonical file).
   Mark `@pytest.mark.xfail(reason="plan 2026-04-27-wire-real-schema-endpoint T1")`.
   Files: `tools/demo-config-mgmt/tests/integration/test_schema_endpoint.py` (new). <!-- orianna: ok -- new test file created by this plan, cross-repo -->
   kind: test. estimate_minutes: 25. DoD: xfail test commit lands before
   impl commit (Rule 12); test runs red on current main; pre-push hook
   green.

2. **T2 — bundle `schema.yaml` into the image.** Implement D1(a): widen
   the Docker build context to `tools/` and add
   `COPY demo-studio-schema/schema.yaml /app/schema.yaml` to the
   `Dockerfile`. Update `deploy.sh` so the `gcloud run deploy --source`
   path points at `tools/` (not `tools/demo-config-mgmt/`) and the
   `--dockerfile` flag (or equivalent) targets
   `demo-config-mgmt/Dockerfile`. Verify locally with
   `docker build -f demo-config-mgmt/Dockerfile tools/` and
   `docker run` listing `/app/schema.yaml`.
   If D1(a) proves infeasible (e.g. Cloud Build context size or
   `.gcloudignore` interactions), fall back to D1(b): `deploy.sh` does
   `cp ../demo-studio-schema/schema.yaml ./schema.yaml` immediately
   before `gcloud run deploy`, and `.gitignore` the local copy in
   `tools/demo-config-mgmt/`.
   Files: `tools/demo-config-mgmt/Dockerfile`, <!-- orianna: ok -- cross-repo path in missmp/company-os -->
   `tools/demo-config-mgmt/deploy.sh`. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
   kind: impl. estimate_minutes: 25. DoD: image built locally contains
   `/app/schema.yaml`; `deploy.sh --dry-run` (or equivalent) prints the
   correct gcloud invocation.

3. **T3 — wire `get_schema` handler; delete stub.** In `main.py`:
   (a) add a module-scope read at import time:
   `_SCHEMA_PATH = Path(__file__).parent / "schema.yaml"`,
   `_SCHEMA_TEXT = _SCHEMA_PATH.read_text(encoding="utf-8")`,
   plus a `yaml.safe_load(_SCHEMA_TEXT)` call wrapped to raise a clear
   `RuntimeError("schema.yaml missing or unparseable: ...")` on failure;
   (b) rewrite `get_schema` to
   `return PlainTextResponse(content=_SCHEMA_TEXT, media_type="text/yaml",
   headers={"Access-Control-Allow-Origin": _CORS_ORIGIN})`;
   (c) delete `MOCK_SCHEMA_YAML` (lines 114-157) and both TODO comments
   (line 117 and line 186);
   (d) confirm `pyyaml` is in `requirements.txt` (already used in
   `main.py` if present; add if not).
   Files: `tools/demo-config-mgmt/main.py`, <!-- orianna: ok -- cross-repo path in missmp/company-os -->
   `tools/demo-config-mgmt/requirements.txt` (if pyyaml missing). <!-- orianna: ok -- cross-repo path in missmp/company-os -->
   kind: impl. estimate_minutes: 20. DoD: file diff removes `MOCK_SCHEMA_YAML`
   constant and both TODO comments; `_SCHEMA_TEXT` populated at import; handler
   serves `_SCHEMA_TEXT` verbatim.

4. **T4 — un-xfail and confirm green.** Remove the `@pytest.mark.xfail`
   marker from `test_schema_endpoint.py`. Run the integration suite
   (`tools/demo-config-mgmt/tests/`) — all assertions pass. Confirm the
   pre-commit unit-test hook (Rule 14) passes for the changed package.
   Files: `tools/demo-config-mgmt/tests/integration/test_schema_endpoint.py`. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
   kind: test. estimate_minutes: 5. DoD: test green on the impl commit;
   no skipped or xfailed assertions remain in the new file.

## QA Plan

**UI involvement:** no

Non-UI branch (server-side endpoint, no browser-renderable artifact). Per
Rule 16, no Akali Playwright run is required for this PR. PR body carries
`QA-Verification:` with the curl + pytest output. The existing demo-studio
Playwright flow is run as a regression check post-deploy (the iframe should
continue to render with no behavior change since it consumes config, not
schema).

### Acceptance criteria

- `GET /v1/schema` (with valid auth) returns HTTP 200, `Content-Type:
  text/yaml`, and a body that parses as YAML.
- Parsed top-level keys are a superset of the canonical `schema.yaml`
  top-level keys.
- Parsed response includes `card`, `params`, `ipadDemo`, `journey`,
  `tokenUi`, `$schema`, `$id` (the seven keys missing from the old stub).
- Response body is byte-equivalent to the bundled `schema.yaml`.
- `MOCK_SCHEMA_YAML` and both TODO comments are removed from `main.py`.
- Service starts cleanly on Cloud Run; cold-start logs show no
  `RuntimeError` from the schema read.

### Happy path (user flow)

1. Local: `pytest tools/demo-config-mgmt/tests/integration/test_schema_endpoint.py -v` → green, all assertions pass.
2. Local: `docker build -f tools/demo-config-mgmt/Dockerfile tools/ -t s2-test` → builds; `docker run --rm s2-test ls /app/schema.yaml` → file present.
3. Stg deploy: `bash tools/demo-config-mgmt/deploy.sh --env stg`; `curl -H "Authorization: Bearer $TOKEN" https://<stg-url>/v1/schema | python -c "import sys,yaml; d=yaml.safe_load(sys.stdin); assert 'card' in d and 'tokenUi' in d; print(sorted(d.keys()))"` → prints full key list including `card`, `params`, `ipadDemo`, `journey`, `tokenUi`.
4. Prod deploy + post-deploy smoke (Rule 17): same curl on prod URL; demo-studio Playwright regression flow runs green (iframe still renders).

### Failure modes (what could break)

- **Schema file missing in image** → service fails to start with clear
  `RuntimeError`. Cloud Run health check fails; auto-rollback per Rule 17.
- **Schema file corrupt / unparseable YAML** → `yaml.safe_load` raises at
  import time, same fail-fast behavior as above.
- **Auth header missing on `/v1/schema`** → `require_auth` raises 401 as
  before; behavior unchanged.
- **Cloud Build context too large after widening to `tools/`** → fall
  back to D1(b) (cp-in-deploy.sh + .gitignore the local copy).
- **CORS origin mismatch on `/v1/schema`** → existing `_CORS_ORIGIN`
  header preserved on the response; demo-studio iframe regression in
  Playwright catches this.

### QA artifacts expected

- `pytest -v` output for `test_schema_endpoint.py` (4 assertions across
  the test body — top-level superset, seven-key presence, byte-equivalence
  snapshot, content-type).
- `curl -i https://<stg-url>/v1/schema` headers + first 50 lines of body.
- `gcloud run services describe demo-config-mgmt --region europe-west1`
  showing the new revision serving traffic.
- Demo-studio Playwright regression report (existing flow, post-deploy).
- `QA-Verification:` line in PR body summarising the four commands above
  with one-line outcomes each.

## References

- `tools/demo-config-mgmt/main.py:114-157, 182-187` — current stub & handler.
- `tools/demo-studio-schema/schema.yaml` — canonical source (524 lines).
- `tools/demo-config-mgmt/api/config-mgmt.yaml` — OpenAPI spec (already documents full config shape).
- `plans/proposed/work/2026-04-27-adr-4-set-config-validation-framing.md` — sibling concern, NOT bundled with this plan.
- Session `e352044b37c04e828c7524c7034fdb75` — origin symptom (agent gaslighting from contract mismatch).
- CLAUDE.md Rule 12 (xfail-first), Rule 14 (pre-commit unit tests), Rule 16 (non-UI QA branch), Rule 17 (post-deploy smoke).
