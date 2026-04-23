# 2026-04-23 — demo-config-mgmt PATCH drift investigation

## Summary

Deployed revision `demo-config-mgmt-00014-2bn` (Cloud Run, europe-west1) was built
**before** commit `fb1ce39` added persistent in-process state to the PATCH handler.
The PATCH route _exists_ at line 238 of main.py in all revisions since 8b0d741
(2026-04-17), but the handler was broken/no-op until fb1ce39 (2026-04-22T01:51Z UTC).

Revision 00014-2bn was created 2026-04-23T08:22Z. The branch HEAD had the fixed
PATCH handler. But the empirical 405 response means the **image** shipped in
00014-2bn does not include the PATCH route — which points to a local-checkout
mismatch: deploy.sh (`gcloud run deploy --source .`) was run from a directory that
did not match the current branch HEAD.

## Key facts

- No CD pipeline exists — only `ci-demo-config-mgmt.yml` (CI only, no deploy job).
- deploy.sh uses `--source .` (builds from local directory, no git SHA embedded).
- Revision metadata has no git SHA annotation (gcloud client deploy, not Cloud Build).
- The drift is a **local-working-tree mismatch**: whoever triggered the deploy on
  2026-04-23T08:22Z did so from a working tree that was behind or dirty relative to
  branch HEAD.

## Recommended action

Redeploy from a clean checkout of feat/demo-studio-v3 HEAD. No source changes needed.
Before deploying, confirm `git status` is clean and `git log -1 -- tools/demo-config-mgmt/main.py`
shows fb1ce39 or later.

## gcloud command used

```
gcloud run services describe demo-config-mgmt --region europe-west1 --project mmpt-233505 --format json
gcloud run revisions list --service demo-config-mgmt --region europe-west1 --project mmpt-233505 --format "table(...)"
git log --all --oneline --format "%H %aI %s" -- tools/demo-config-mgmt/main.py
```
