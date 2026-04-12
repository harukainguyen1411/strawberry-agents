---
title: Dark Strawberry — Deployment Architecture
status: proposed
owner: swain
date: 2026-04-12
tags: [architecture, deployment, ci-cd, darkstrawberry]
---

# Dark Strawberry — Deployment Architecture

## Problem

The current deployment setup has grown organically and has several pain points:

1. **Path triggers are fragile** — `myapps-prod-deploy.yml` watches `apps/myapps/**`, `apps/platform/**`, `apps/shared/**`, `apps/myApps/**`, `apps/yourApps/**` but the build still runs from `apps/myapps/` only. A change in `apps/shared/` triggers a deploy but the build might not pick up the change correctly if imports aren't resolved.
2. **No staging** — PRs get a preview channel, but merges to main go straight to production. No way to verify a deploy before it hits users.
3. **Landing and portal are completely separate pipelines** with different deploy mechanisms (one uses `FirebaseExtended/action-hosting-deploy`, the other uses raw `firebase-tools` CLI).
4. **Cloud Functions have no CI/CD** — `apps/functions/` exists but has no workflow. Deploy is manual (`firebase deploy --only functions`).
5. **Firestore rules have no CI/CD** — `apps/myapps/firestore.rules` is deployed manually. No validation, no staging.
6. **No versioning** — no way to know what's deployed or roll back to a known state.
7. **No rollback plan** — if a deploy breaks, the only option is to push a fix forward.

## Deployment Targets

| Target | Source | Domain | Firebase Site | Deploy Method |
|--------|--------|--------|---------------|---------------|
| **Portal** (apps platform) | `apps/myapps/` (builds from `apps/platform/`, `apps/shared/`, `apps/myApps/`, `apps/yourApps/`) | `apps.darkstrawberry.com` | default site | Firebase Hosting via GitHub Action |
| **Landing page** | `apps/landing/` | `darkstrawberry.com` | `darkstrawberry-landing` | Firebase Hosting via GitHub Action |
| **Cloud Functions** | `apps/functions/` | n/a | n/a | `firebase deploy --only functions` via GitHub Action |
| **Firestore Rules** | `apps/myapps/firestore.rules` | n/a | n/a | `firebase deploy --only firestore:rules` via GitHub Action |
| **Storage Rules** | `apps/myapps/storage.rules` | n/a | n/a | `firebase deploy --only storage` via GitHub Action |

## Monorepo Build Model

The portal is a single Vite build rooted at `apps/myapps/`. It imports from sibling directories via Vite aliases:

```
apps/myapps/          # Vite root, package.json, node_modules
  vite.config.ts      # Aliases: @platform -> ../platform/src, @shared -> ../shared, etc.
  src/                # App shell, router, stores
apps/platform/src/    # Platform chrome (nav, auth, app loader)
apps/shared/          # Firebase helpers, types, UI components
apps/myApps/          # Public app modules (read-tracker, portfolio-tracker, task-list)
apps/yourApps/        # Personal app modules (bee, forks)
apps/functions/       # Cloud Functions (separate build, separate deploy)
apps/landing/         # Static HTML landing page (separate deploy)
```

A change in **any** of `apps/myapps/`, `apps/platform/`, `apps/shared/`, `apps/myApps/`, `apps/yourApps/` affects the portal build. Changes in `apps/functions/` and `apps/landing/` are independent.

## Workflow Architecture

### Overview

```
PR opened/updated
  |
  +--> [portal-test]      Unit + E2E tests (if portal paths changed)
  +--> [portal-preview]   Preview channel deploy (if portal paths changed)
  +--> [functions-test]   Lint + build check (if functions paths changed)
  +--> [rules-validate]   firebase rules validate (if rules changed)
  |
  All checks pass -> merge to main
  |
  +--> [portal-staging]   Deploy to staging channel, wait for manual approval
  |      |
  |      +--> [portal-prod]  Deploy to live (after approval)
  |
  +--> [landing-deploy]   Deploy landing page to prod (no staging — static HTML)
  +--> [functions-deploy]  Deploy Cloud Functions to prod
  +--> [rules-deploy]     Deploy Firestore + Storage rules to prod
```

### 1. Portal Deploy Pipeline (`portal-deploy.yml`)

Replaces `myapps-prod-deploy.yml`. Two-stage: staging then production.

```yaml
name: Portal — Deploy

on:
  push:
    branches: [main]
    paths:
      - 'apps/myapps/**'
      - 'apps/platform/**'
      - 'apps/shared/**'
      - 'apps/myApps/**'
      - 'apps/yourApps/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm, cache-dependency-path: apps/myapps/package-lock.json }
      - run: npm ci
        working-directory: apps/myapps
      - run: npm run build
        working-directory: apps/myapps
        env: { ... VITE_FIREBASE_* secrets ... }
      - uses: actions/upload-artifact@v4
        with: { name: portal-dist, path: apps/myapps/dist/ }

  staging:
    needs: build
    runs-on: ubuntu-latest
    environment: staging          # GitHub Environment — no approval gate
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with: { name: portal-dist, path: apps/myapps/dist/ }
      - uses: FirebaseExtended/action-hosting-deploy@v0
        id: staging_deploy
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          projectId: ${{ vars.FIREBASE_PROJECT_ID }}
          channelId: staging
          entryPoint: apps/myapps
          expires: 7d
      # Post staging URL to Discord for verification
      - name: Notify Discord — staging ready
        env:
          DISCORD_RELAY_WEBHOOK_URL: ${{ secrets.DISCORD_RELAY_WEBHOOK_URL }}
          DISCORD_RELAY_WEBHOOK_SECRET: ${{ secrets.DISCORD_RELAY_WEBHOOK_SECRET }}
          STAGING_URL: ${{ steps.staging_deploy.outputs.details_url }}
          COMMIT_MESSAGE: ${{ github.event.head_commit.message }}
        run: |
          # Post staging notification (reuse existing notify script pattern)
          echo "Staging deployed: $STAGING_URL"

  production:
    needs: staging
    runs-on: ubuntu-latest
    environment: production       # GitHub Environment — requires manual approval
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with: { name: portal-dist, path: apps/myapps/dist/ }
      - uses: FirebaseExtended/action-hosting-deploy@v0
        id: prod_deploy
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          channelId: live
          projectId: ${{ vars.FIREBASE_PROJECT_ID }}
          entryPoint: apps/myapps
      - name: Notify Discord — shipped
        if: success()
        env:
          DISCORD_RELAY_WEBHOOK_URL: ${{ secrets.DISCORD_RELAY_WEBHOOK_URL }}
          DISCORD_RELAY_WEBHOOK_SECRET: ${{ secrets.DISCORD_RELAY_WEBHOOK_SECRET }}
          COMMIT_MESSAGE: ${{ github.event.head_commit.message }}
          REPO: ${{ github.repository }}
          FIREBASE_PROJECT_ID: ${{ vars.FIREBASE_PROJECT_ID }}
        run: node .github/scripts/notify-discord-shipped.js
      # Tag the release
      - name: Tag release
        run: |
          VERSION="portal-$(date +%Y%m%d)-$(echo ${{ github.sha }} | cut -c1-7)"
          git tag "$VERSION"
          git push origin "$VERSION"
```

**Key design decisions:**
- **Build once, deploy twice** — the `build` job uploads an artifact. Both staging and production deploy the same artifact. This eliminates "works in staging but not in prod" from environment differences.
- **GitHub Environments** — `staging` has no approval gate (auto-deploys). `production` requires manual approval from Duong. This gives a window to verify staging before promoting.
- **Staging channel** — uses Firebase Hosting preview channels. The `staging` channel name is fixed (not per-PR), so there's always one staging URL to bookmark.

### 2. Landing Page Deploy (`landing-deploy.yml`)

Replaces `landing-prod-deploy.yml`. Simplified — no staging needed for static HTML.

```yaml
name: Landing — Deploy

on:
  push:
    branches: [main]
    paths:
      - 'apps/landing/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          channelId: live
          projectId: ${{ vars.FIREBASE_PROJECT_ID }}
          entryPoint: apps/landing
```

Switches from raw `firebase-tools` CLI to `FirebaseExtended/action-hosting-deploy@v0` for consistency with the portal pipeline. The `site` field in `apps/landing/firebase.json` already targets `darkstrawberry-landing`.

### 3. Cloud Functions Deploy (`functions-deploy.yml`)

New workflow.

```yaml
name: Functions — Deploy

on:
  push:
    branches: [main]
    paths:
      - 'apps/functions/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
        working-directory: apps/functions
      - run: npm run build
        working-directory: apps/functions
      - name: Write service account key
        env:
          FIREBASE_SERVICE_ACCOUNT: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
        run: echo "$FIREBASE_SERVICE_ACCOUNT" > /tmp/sa.json
      - name: Deploy functions
        working-directory: apps/functions
        env:
          GOOGLE_APPLICATION_CREDENTIALS: /tmp/sa.json
        run: npx firebase-tools@latest deploy --only functions --project ${{ vars.FIREBASE_PROJECT_ID }} --non-interactive
```

### 4. Firestore & Storage Rules Deploy (`rules-deploy.yml`)

New workflow.

```yaml
name: Rules — Deploy

on:
  push:
    branches: [main]
    paths:
      - 'apps/myapps/firestore.rules'
      - 'apps/myapps/storage.rules'

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production       # Requires approval — rules affect all users immediately
    steps:
      - uses: actions/checkout@v4
      - name: Write service account key
        env:
          FIREBASE_SERVICE_ACCOUNT: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
        run: echo "$FIREBASE_SERVICE_ACCOUNT" > /tmp/sa.json
      - name: Deploy rules
        working-directory: apps/myapps
        env:
          GOOGLE_APPLICATION_CREDENTIALS: /tmp/sa.json
        run: npx firebase-tools@latest deploy --only firestore:rules,storage --project ${{ vars.FIREBASE_PROJECT_ID }} --non-interactive
```

### 5. PR Validation (`rules-validate.yml`)

New workflow — validates rules on PRs before merge.

```yaml
name: Rules — Validate

on:
  pull_request:
    branches: [main]
    paths:
      - 'apps/myapps/firestore.rules'
      - 'apps/myapps/storage.rules'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Write service account key
        env:
          FIREBASE_SERVICE_ACCOUNT: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
        run: echo "$FIREBASE_SERVICE_ACCOUNT" > /tmp/sa.json
      - name: Validate Firestore rules
        env:
          GOOGLE_APPLICATION_CREDENTIALS: /tmp/sa.json
        run: npx firebase-tools@latest --project ${{ vars.FIREBASE_PROJECT_ID }} firestore:rules:validate apps/myapps/firestore.rules
```

### 6. Functions Test (`functions-test.yml`)

New workflow — validates functions build on PRs.

```yaml
name: Functions — Test

on:
  pull_request:
    branches: [main]
    paths:
      - 'apps/functions/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
        working-directory: apps/functions
      - run: npm run build
        working-directory: apps/functions
```

## Versioning Strategy

**Git tags** as the version source of truth. Format: `{target}-{YYYYMMDD}-{short-sha}`.

Examples:
```
portal-20260412-abc1234
landing-20260412-def5678
functions-20260412-ghi9012
rules-20260412-jkl3456
```

Tags are created automatically by the production deploy jobs. This gives:
- A clear record of what's deployed and when
- Easy `git diff` between any two releases: `git diff portal-20260411-xxx portal-20260412-yyy`
- A rollback target (see below)

No semver — this is a single-tenant platform, not a published package. Date-based tags are simpler and more informative.

## Rollback Plan

### Portal Rollback

Firebase Hosting keeps the last several deploys. Rollback options:

1. **Firebase Console** — one-click rollback to any previous deploy in the Firebase Hosting console. Fastest option (< 1 minute).
2. **Redeploy a tag** — trigger a manual workflow run that checks out a specific tag and deploys:

```yaml
# Add to portal-deploy.yml
on:
  workflow_dispatch:
    inputs:
      tag:
        description: 'Git tag to deploy (e.g. portal-20260411-abc1234)'
        required: true
```

3. **Revert commit** — `git revert` the bad commit, push to main, pipeline runs automatically.

### Functions Rollback

Cloud Functions doesn't have one-click rollback. Options:
1. **Revert commit** — push a revert, let the pipeline redeploy.
2. **Manual deploy from tag** — check out the tag locally, run `firebase deploy --only functions`.

### Rules Rollback

Same as functions — revert the commit or deploy manually from a known-good tag. Rules deploys require the `production` environment approval gate, so bad rules should be caught before they ship.

## GitHub Environments Setup

Two environments need to be created in the repo settings:

| Environment | Approval Required | Used By |
|-------------|-------------------|---------|
| `staging` | No | Portal staging deploy |
| `production` | Yes (Duong) | Portal prod deploy, Rules deploy |

## Workflow Summary

| Workflow | Trigger | Path Filter | Environment Gate |
|----------|---------|-------------|------------------|
| `portal-test.yml` | PR | `apps/(myapps\|platform\|shared\|myApps\|yourApps)/` | none |
| `portal-preview.yml` | PR | `apps/(myapps\|platform\|shared\|myApps\|yourApps)/` | none |
| `portal-deploy.yml` | push to main | `apps/(myapps\|platform\|shared\|myApps\|yourApps)/` | staging -> production |
| `landing-deploy.yml` | push to main | `apps/landing/` | none |
| `functions-test.yml` | PR | `apps/functions/` | none |
| `functions-deploy.yml` | push to main | `apps/functions/` | none |
| `rules-validate.yml` | PR | `apps/myapps/(firestore\|storage).rules` | none |
| `rules-deploy.yml` | push to main | `apps/myapps/(firestore\|storage).rules` | production |

## Migration Steps

### Phase 1: Set up environments and new workflows
1. Create `staging` and `production` GitHub Environments in repo settings
2. Add Duong as required reviewer for `production` environment
3. Create `functions-deploy.yml`, `functions-test.yml`, `rules-deploy.yml`, `rules-validate.yml`
4. Create `portal-deploy.yml` (the new staging->production pipeline)
5. Update `landing-deploy.yml` to use `FirebaseExtended/action-hosting-deploy`

### Phase 2: Cut over
1. Rename old `myapps-prod-deploy.yml` to `portal-deploy.yml` (or delete and create new)
2. Keep `myapps-pr-preview.yml` and `myapps-test.yml` as-is (rename to `portal-preview.yml` and `portal-test.yml` for consistency)
3. Delete old `landing-prod-deploy.yml`
4. Verify all paths trigger correctly with a test PR

### Phase 3: Add rollback capability
1. Add `workflow_dispatch` trigger with tag input to `portal-deploy.yml`
2. Document rollback procedures in `architecture/deployment.md`

## Open Questions

None. This plan is self-contained and ready for implementation.
