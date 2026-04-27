# Learning: demo-studio-v3 PROD deploy — PRs #126-#129

Date: 2026-04-27
Topic: Clean prod deploy of feat/demo-studio-v3 with PRs #126, #127, #128, #129

## Target SHA

f313b927d9f7ae023e9401ebd905e7b4dc3c6e73 (short: f313b92)

## Hard Gate Results

1. SHA pinned from `git fetch origin feat/demo-studio-v3` + `git rev-parse`.
2. Working tree was CLEAN — used a detached `git worktree add --detach /tmp/demo-studio-prod-deploy f313b92` instead of touching the dirty main working tree (which had test-results.json modified). This satisfies the no-stash rule — worktree approach gives a pristine tree without stash gymnastics.
3. /__build_info verified: `{"revision":"f313b927d9f7","builtAt":"2026-04-27T16:09:43Z","service":"demo-studio-v3"}`.
4. /health 200 `{"status":"ok"}`.
5. Full smoke: /health 200, /debug 200 (firestore fields present), POST /session 201 (sessionId + studioUrl returned), GET /auth/session redirect 303, follow redirect 200 (session page with __sessionId), /static/studio.js 200, /static/studio.css 200, /dashboard 200. ALL PASS.

## Deploy mechanics

- Source deploy: `cd /tmp/demo-studio-prod-deploy/tools/demo-studio-v3 && BASE_URL=... MANAGED_AGENT_ID=disabled MANAGED_ENVIRONMENT_ID=disabled MANAGED_VAULT_ID=disabled bash deploy.sh`
- deploy.sh emits "serving 100% of old revision" when service has pinned traffic — always follow with explicit traffic switch.
- Traffic switch: `gcloud run services update-traffic demo-studio --project=mmpt-233505 --region=europe-west1 --to-revisions=demo-studio-00041-5h8=100`

## New revision

demo-studio-00041-5h8

## Rollback target

demo-studio-00040-kgk (SHA 24b1e22, was 100% before this deploy)

## smoke-test.sh macOS bug

`head -n -1` in scripts/smoke-test.sh is BSD-incompatible (GNU head only). On macOS, run checks manually instead of relying on the script. All 8 test cases verified manually in this session.

## Prod service note

There is only one `demo-studio` Cloud Run service — it is the prod/stg combined service at https://demo-studio-4nvufhmjiq-ew.a.run.app (also aliased as https://demo-studio-266692422014.europe-west1.run.app).
