# Learning: demo-studio-v3 redeploy — PRs #126 + #127

Date: 2026-04-27
Topic: Cloud Run staging deploy for demo-studio-v3 after PRs #126 and #127 merged

## What happened

Deployed feat/demo-studio-v3 HEAD (24b1e22) after PRs #126 (422 defensiveness) and #127
(deployBtn-only build trigger, trigger_factory removal) merged into the branch.

New revision: demo-studio-00052-tow
Service URL: https://demo-studio-4nvufhmjiq-ew.a.run.app
Smoke: /health → 200 {"status":"ok"}

## Stale staged files pattern

The company-os working tree had config_mgmt_client.py and main.py staged but not committed.
These were staging artifacts from a prior session (the PR work before merge). The local branch
was 2 commits behind origin. Resolution:
1. `git restore --staged <files>` to unstage
2. `git stash` to park working-tree modifications
3. `git merge origin/feat/demo-studio-v3` (fast-forward — clean)
4. `git stash drop` (changes now in origin content, stash is redundant)

## --to-latest vs explicit revision

`gcloud run services update-traffic --to-latest` pointed to a stale pinned LATEST
(demo-studio-00039-qz7) rather than the newly built revision. Always use explicit
`--to-revisions=<rev>=100` after a source deploy to guarantee the new revision gets traffic.

## Rollback

Previous serving revision: demo-studio-00039-qz7 (100% before this deploy)
Rollback: `gcloud run services update-traffic demo-studio --project=mmpt-233505 --region=europe-west1 --to-revisions=demo-studio-00039-qz7=100`
