# 2026-04-22 — deploy.sh secret name repeatedly stomped by Viktor commits

## Pattern

`tools/demo-config-mgmt/deploy.sh` uses `--set-secrets=CONFIG_MGMT_TOKEN=DS_CONFIG_MGMT_TOKEN:latest`.
Viktor's commits have reset this to the stale lowercase name `ds-config-mgmt-token` at least twice.

## Fix applied this session

Commit 4cbcebf on `feat/demo-studio-v3`:
`ops(demo-config-mgmt): fix deploy.sh secret name DS_CONFIG_MGMT_TOKEN`

## Recommendation

If this recurs a third time, flag to Duong/Sona that Viktor's agent definition or plan template
has a stale literal for the secret name. The fix should go into Viktor's source context, not just
re-applied post-hoc.
