# 2026-04-22 — demo-studio S1 + demo-config-mgmt S2 F-01/F4 deploy

## Context

Morning-demo blocker. Viktor landed F-01 (web_search_20241022 deprecated type → web_search),
F-02 (UI silent failure), F3 (SSE nonce-abort history persistence), F4 (brand race — in-process
session config store in demo-config-mgmt) as commits 974550e, b16cdb4, fb1ce39 on feat/demo-studio-v3.

## What happened

- company-os was already at fb1ce39 on feat/demo-studio-v3 — no pull needed.
- S1 (demo-studio) deployed successfully on first attempt. New revision: demo-studio-00027-xqv.
- S2 (demo-config-mgmt) failed on first attempt: secret ref `ds-config-mgmt-token` not found.
  - deploy.sh reverted to stale lowercase-kebab secret name from before the 2026-04-22 fix.
  - Viktor's F4 commit must have reset deploy.sh back to the stale ref, OR the file was never
    committed with the corrected name after our prior fix (we only patched it locally).
  - Fix: changed `ds-config-mgmt-token` → `DS_CONFIG_MGMT_TOKEN` in deploy.sh (in-place edit).
- S2 redeployed successfully. New revision: demo-config-mgmt-00012-5pl.
- IAM policy warning on S2 is cosmetic (service is --no-allow-unauthenticated, no public invoker).

## Key facts

- S1 new revision: demo-studio-00027-xqv
- S2 new revision: demo-config-mgmt-00012-5pl
- S1 Service URL: https://demo-studio-4nvufhmjiq-ew.a.run.app (also https://demo-studio-266692422014.europe-west1.run.app)
- S2 Service URL: https://demo-config-mgmt-4nvufhmjiq-ew.a.run.app
- S1 smoke: HTTP 200
- Commit deployed: fb1ce39

## Action item

`tools/demo-config-mgmt/deploy.sh` fix (ds-config-mgmt-token → DS_CONFIG_MGMT_TOKEN) was applied
locally in company-os. This should be committed to feat/demo-studio-v3 so it persists across future
deploys. Otherwise every S2 deploy will hit this failure.
