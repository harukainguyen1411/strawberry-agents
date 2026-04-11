# Handoff

## State
PR #89 (feat/windows-push-autodeploy) approved by Lissandra — ready to merge. docs/windows-services-runbook.md written and committed to main (fac563d). Session closing in progress.

## Next
1. Merge PR #89 (feat/windows-push-autodeploy) into main.
2. On Windows box: run `scripts/windows/install-deploy-webhook.ps1`, fill in `webhook.env`, set up GitHub webhook per `docs/windows-services-runbook.md`.
3. Verify autodeploy works end-to-end with a test push.

## Context
- deploy-webhook secrets live at `%USERPROFILE%\deploy-webhook\secrets\webhook.env` (NTFS ACL protected, not in repo)
- DEPLOY_REPO_ROOT must be set in webhook.env — process.cwd() is wrong under NSSM
- Stale lock threshold is 10 min — lock file is at `apps/deploy-webhook/deploy.lock`
