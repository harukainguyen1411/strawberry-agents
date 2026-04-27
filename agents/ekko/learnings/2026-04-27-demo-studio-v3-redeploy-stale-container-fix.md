# Learning: demo-studio-v3 redeploy — stale container fix

Date: 2026-04-27
Topic: Re-deploy after stale working tree produced wrong container image (revision 6f8ea1b)

## What happened

Previous deploy (demo-studio-00052-tow) reported BUILD_SHA=24b1e22fd114 in the env var but
`/__build_info` returned `revision: "6f8ea1b"` — the pre-#126/#127 commit. The container
image was built from a stale tree despite the metadata looking correct. Root cause: the
stash/fast-forward/unstash wrinkle in the prior session caused the source upload to Cloud
Build to include the old working tree state.

## Fix

1. Confirmed working tree was clean and at 24b1e22 (`git status --porcelain` = empty,
   `git rev-parse HEAD` = 24b1e22fd1145e5d6d64def0530a11ebbe4feaa2).
2. Re-ran deploy.sh from scratch — deploy.sh has a built-in dirty-tree guard (exits 1 if
   `git status --porcelain` is non-empty) so a dirty tree would have been caught.
3. New revision: demo-studio-00040-kgk (generation 40), built at 2026-04-27T15:04:42Z.
4. Switched traffic explicitly to the new revision:
   `gcloud run services update-traffic demo-studio ... --to-revisions=demo-studio-00040-kgk=100`
5. Verified `/__build_info` → `{"revision":"24b1e22fd114","builtAt":"2026-04-27T15:04:42Z"}`

## Revision numbering gap

Revisions jumped from 00039 to 00052 (from the prior deploy session) and now to 00040 —
Cloud Run revision numbers are NOT monotonically sequential per session; they reflect
configuration generation and can appear non-linear when multiple deploy attempts happen.
Revision name != generation order for traffic-management decisions — always use explicit
`--to-revisions=<name>=100` after confirming the correct revision name.

## deploy.sh behavior note

`gcloud run deploy --source` sets 0% traffic on new revision when the service already has
pinned traffic routing (explicit `--to-revisions` was set before). Always follow source
deploy with an explicit `--to-revisions=<newrev>=100` traffic switch.

## Rollback

Previous serving revision: demo-studio-00052-tow (100% before this deploy)
Rollback: `gcloud run services update-traffic demo-studio --project=mmpt-233505 --region=europe-west1 --to-revisions=demo-studio-00052-tow=100`
