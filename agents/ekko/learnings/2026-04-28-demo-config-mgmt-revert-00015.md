# demo-config-mgmt revert: 00017-f5n → 00015-c7b

**Date:** 2026-04-28
**Task:** Urgent prod revert — session→config binding broken after today's PR #130/#133 deploys.

## What happened

Revision 00017-f5n (SHA e52c94c8, PRs #130 + #133) was deployed earlier today.
Bug: POST /v1/config returns 201 but GET /v1/config/{session_id} returns seed (Allianz).

## Tuan.pham revision identification

The task asked to find the "tuan.pham revision" by checking git author of Cloud Run revision SHA labels.
Result: only revisions 00015–00017 have SHA labels; all 3 are Duong's commits (duongntd99 / Duongntd).
Older revisions (00001–00014) have no `commit-sha` label.

tuan.pham's last commit to demo-config-mgmt was `0b1b679299` (2026-04-20, CI pipeline addition),
merged to main via PR #41 on 2026-04-20. ALL revisions from 00009 onwards include tuan's code.
None of the labeled revisions have tuan as direct git author.

Conclusion: "tuan's revision" means the last revision that was working before today's broken deploy,
i.e., 00015-c7b (SHA 24b1e22fd114, deployed 2026-04-27, PR #117 min-instances=1 only change).

## Traffic flip

`gcloud run services update-traffic demo-config-mgmt --region europe-west1 --project mmpt-233505 --to-revisions=demo-config-mgmt-00015-c7b=100`

Completed successfully. 100% traffic now on 00015-c7b.

## Smoke verification: binding

- session_id: smoke-89cade4042ac401797437e4f15cf1be7 (fresh, not reused)
- POST /v1/config with brand="Aviva-revert-test": HTTP 201
- GET /v1/config/{session_id}: HTTP 200, brand="Aviva-revert-test"
- **BINDING: PASS — POST-written value survives GET**

## Smoke verification: /v1/schema

00015-c7b serves the **MOCK STUB** schema (not canonical):
- Body: ~1031 bytes
- Content: 11-field stub with brand/market/languages/shortcode/colors/logos only
- Fields absent: card, params, ipadDemo, journey, tokenUi
- Contains: "TODO: implement — return the real schema.yaml content from Firestore or bundled file"

Evelynn's course-correction assumption (that tuan's revision had canonical schema) was incorrect.
The canonical schema was introduced by PR #130 (the broken revision). 00015 predates it.

## What PR #130 and PR #133 work is lost

**PR #130 (chore: wire /v1/schema to canonical schema.yaml)**
- /v1/schema now returns mock stub (11 fields) instead of canonical schema.yaml (19377 bytes, all fields)
- main.py loses: import yaml, import Path, _SCHEMA_PATH, _SCHEMA_TEXT module-level schema load
- main.py loses: fail-fast RuntimeError on missing/corrupt schema.yaml

**PR #133 (chore: add .gcloudignore to stage dir)**
- deploy.sh loses: STAGE_DIR mktemp isolation, schema.yaml copy into stage dir, empty .gcloudignore
- deploy.sh loses: --source "${STAGE_DIR}" → reverted to --source .
- tools/demo-config-mgmt/.gitignore (new file, excludes schema.yaml) is lost

Both PRs need re-application on top of a new branch off 00015's HEAD (24b1e22fd114).

## Root cause hypothesis for binding bug

The session_store code is identical between 00015 and 00017 — same in-memory dict logic.
The binding bug may be environmental (Cloud Run cold-start / instance split between POST and GET
on different instances with --min-instances=1 not applying to 00017's new revision scale-up).
Or the bug may have been a transient issue with the specific 00017 container build.
The revert to 00015 fixed it — binding confirmed passing with same min-instances=1 config.

## Auth pattern

Service uses static bearer token from Secret Manager secret DS_CONFIG_MGMT_TOKEN.
Identity tokens return 401 (per earlier learning). Use `Authorization: Bearer <token>` only.
Token retrieved via: `gcloud secrets versions access latest --secret=DS_CONFIG_MGMT_TOKEN --project=mmpt-233505`
