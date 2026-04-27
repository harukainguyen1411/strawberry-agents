# 2026-04-28 — demo-config-mgmt schema deploy (PR #130 + PR #133)

## What was done

Resumed aborted deploy of demo-config-mgmt after PR #133 (.gcloudignore fix) merged into
`feat/demo-studio-v3`. Used a detached worktree at origin/feat/demo-studio-v3 HEAD
(`e52c94c`) to satisfy deploy.sh's dirty-tree guard without touching the main checkout.

## Key findings

- **demo-config-mgmt has no `/__build_info` endpoint** — SHA verification must use the
  `git-sha` Cloud Run label (`gcloud run services describe ... --format="value(metadata.labels.git-sha)"`).
  Label value: `e52c94c8cffd` matching branch HEAD.

- **Auth method**: demo-config-mgmt uses a static bearer token from secret
  `DS_CONFIG_MGMT_TOKEN`, not Cloud Run identity tokens. Identity tokens return 401.
  Use `gcloud secrets versions access latest --secret=DS_CONFIG_MGMT_TOKEN` piped via env
  var to avoid transcript exposure.

- **stg = prod for demo-config-mgmt** — same single Cloud Run service, no separate stg.
  Confirmed again from 2026-04-25 learning.

- **Schema smoke result**: `/v1/schema` returned 200, Content-Type: `text/yaml; charset=utf-8`,
  19377 bytes. All canonical fields present (card, params, ipadDemo, journey, tokenUi).
  MOCK_SCHEMA_YAML absent. The .gcloudignore fix worked — schema.yaml was correctly
  included in the Cloud Build upload.

## Revision

- Previous (last-known-good): `demo-config-mgmt-00015-c7b`
- New revision: `demo-config-mgmt-00017-f5n` (100% traffic)

## Pattern: worktree for deploy from dirty main checkout

When the main checkout is dirty (unrelated test result files) and deploy.sh checks
`git status --porcelain`, use `git worktree add /tmp/<dir> origin/<branch>` for a clean
isolated deploy context. Remove with `git worktree remove --force` after deploy.
