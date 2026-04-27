# 2026-04-27 — demo-config-mgmt min-instances=1 redeploy

## Task

Redeploy `demo-config-mgmt` (S2) to prod so PR #117's `--min-instances=1` change
takes effect. Prior live revision `demo-config-mgmt-00014-2bn` (2026-04-23T08:22Z)
was built before PR #117 merged (2026-04-24T09:18Z, commit `f83d4b5e`), so
`autoscaling.knative.dev/minScale` was empty on the live revision.

## Steps taken

1. `git fetch origin feat/demo-studio-v3` from `/Documents/Work/mmp/workspace/company-os`.
   Confirmed `f83d4b5e` in history (`ops: add --min-instances=1 to demo-config-mgmt deploy`).
2. Confirmed `tools/demo-config-mgmt/deploy.sh` has `--min-instances=1` on line 23.
3. Confirmed gcloud account: `duong.nguyen.thai@missmp.eu` (correct for mmpt-233505).
4. Working tree was clean (`git status --porcelain` empty), HEAD `24b1e22`.
5. Ran `bash deploy.sh` from `tools/demo-config-mgmt/` — wall time ~3min.
6. New revision: `demo-config-mgmt-00015-c7b`, 100% traffic.
7. Verified `minScale: 1` via `gcloud run revisions list`.
8. Smoke: `curl .../v1/config/00000000-...` → HTTP 401 (UNAUTHORIZED, not 503).
   401 is correct — service is `--no-allow-unauthenticated`.

## Result

- New revision: `demo-config-mgmt-00015-c7b`
- `minScale`: `1`
- Smoke: 401 (service live, not cold-start failing)

## Key facts

- deploy.sh must be run from `tools/demo-config-mgmt/` (uses `--source .`).
- IAM policy warning ("Setting IAM policy failed") is cosmetic — same as prior deploys.
- Service URL: `https://demo-config-mgmt-266692422014.europe-west1.run.app`
- Rollback target (previous revision): `demo-config-mgmt-00014-2bn`
