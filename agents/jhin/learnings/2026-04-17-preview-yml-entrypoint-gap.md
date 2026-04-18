---
name: preview.yml entryPoint gap pattern
description: When root firebase.json is deleted, preview.yml breaks because action-hosting-deploy defaults to repo root with no entryPoint set
type: feedback
---

When a PR deletes root `firebase.json` and adds a `cp` staging step to `release.yml`, always grep ALL workflows for `action-hosting-deploy` invocations without `entryPoint`. `preview.yml` is a second portal preview workflow that duplicates the hosting deploy pattern without `entryPoint` — it will silently break.

**Why:** PR #137 fixup 2 added the staging step to `release.yml` deploy-portal job but missed `preview.yml`, which also uses `action-hosting-deploy@v0` without `entryPoint`. Root firebase.json deletion broke it.

**How to apply:** Any time root `firebase.json` is moved or deleted, grep `.github/workflows/` for `action-hosting-deploy` and verify every invocation either has `entryPoint` set or receives the staging `cp` step before it.
