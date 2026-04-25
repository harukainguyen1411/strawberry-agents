# 2026-04-25 — T.P1.14 final ship deploy (demo-factory + demo-studio-v3)

## Task

T.P1.14 from plans/in-progress/work/2026-04-22-p1-factory-build-ipad-link.md — deploy
demo-factory (task's S1) and demo-studio-v3 (task's S3) stg → prod, 100% traffic, no canary.
Critical env: `FACTORY_REAL_BUILD=1` on demo-factory prod.

## PREV revisions (before this session)

- demo-factory: `demo-factory-00010-645`
- demo-studio: `demo-studio-00028-2n2`

## Deploy sequence and outcomes

### Pre-deploy

- T.P1.12 xfail status verified: `TestP112IntegrationHappyPath` and `TestP112IntegrationFailurePath`
  methods are NOT decorated with `@P1_XFAIL` — implementation was committed at `64eb362`
  ("T.P1.12 — wire S1 /build to in-process S3 pipeline; flip xfail tests green").
- Ran `python -m pytest tests/test_build_endpoint.py` — 4 passed, 0 failed.
- Working tree had 2 dirty files: `test-results.json` + `test-run-history.json` (test artifacts
  from running P1.12 tests). Committed as `ab51372`, pushed to feat/demo-studio-v3.

### S1 stg (demo-factory)

- Command: `bash deploy.sh` from `tools/demo-factory/` (no env vars needed — hardcoded in deploy.sh)
- New revision: `demo-factory-00011-wpv`
- Traffic: 100%
- IAM warning: cosmetic (pre-existing, no-allow-unauthenticated service)
- Smoke: `/health` → 200, `/build/nonexistent` → 401 (auth layer active) — GREEN

### S3 stg (demo-studio-v3)

- Command: `BASE_URL=... MANAGED_AGENT_ID=... MANAGED_ENVIRONMENT_ID=... MANAGED_VAULT_ID=... bash deploy.sh`
- New revision: `demo-studio-00029-8bk`
- Traffic: 100%
- Smoke: `/health` → 200, `/debug` → 200 (firestore=ok, anthropic=ok, startup_complete),
  `/static/studio.js` → 200, `/static/studio.css` → 200, `/dashboard` → 200 — GREEN

### S1 prod (demo-factory FACTORY_REAL_BUILD=1)

- Command: `gcloud run services update demo-factory --update-env-vars="FACTORY_REAL_BUILD=1"`
  (no rebuild needed — code already deployed at 00011-wpv; update just flips the env var)
- New revision: `demo-factory-00012-9mg`
- Traffic: 100%
- Smoke: `/health` → `{"status":"ok"}` 200, `/build/nonexistent` → 401 — GREEN

### S3 prod (demo-studio-v3)

- No separate prod step needed — `demo-studio-00029-8bk` IS the prod revision.
  demo-studio-v3 has no FACTORY_REAL_BUILD flag; the flag is on demo-factory.
- Final prod smoke: `/health` → 200, `/static/studio.js` → 200 — GREEN

## Final revisions (post-deploy)

- demo-factory: `demo-factory-00012-9mg` (FACTORY_REAL_BUILD=1, 100% traffic)
- demo-studio: `demo-studio-00029-8bk` (100% traffic)

## Service URLs

- demo-factory: https://demo-factory-266692422014.europe-west1.run.app
- demo-studio: https://demo-studio-266692422014.europe-west1.run.app

## Stg vs prod environment clarification

There are NO separate stg/prod Cloud Run services for demo-factory or demo-studio. The single
`demo-studio` service uses `FIRESTORE_DATABASE=demo-studio-staging` (the only Firestore DB for
this service — no `demo-studio-prod` database exists). The "stg → prod" sequence in the task meant:
- stg: deploy new code with FACTORY_REAL_BUILD=0 (initial code ship, verification)
- prod: flip FACTORY_REAL_BUILD=1 via `gcloud run services update` (real pipeline active)

`scripts/deploy/rollback.sh` does not exist in strawberry-agents/scripts/deploy/. If smoke had
failed, rollback would be: `gcloud run services update-traffic demo-factory --to-revisions=PREV=100`
(or equivalent for demo-studio). No auto-rollback was needed.

## Task labeling note

Task uses S1=demo-factory, S3=demo-studio-v3. Plan ADR uses S1=demo-studio-v3, S3=demo-factory.
These are inverted. The critical env var `FACTORY_REAL_BUILD=1` lives on demo-factory regardless
of naming. The task's phrase "must be set on the demo-studio-v3 prod deploy" is an error in the
task — it should say "demo-factory prod deploy." Proceeded with the correct target.

## Rollback revisions

- demo-factory: `demo-factory-00010-645` (pre-session, FACTORY_REAL_BUILD=0)
- demo-studio: `demo-studio-00028-2n2` (pre-session)
