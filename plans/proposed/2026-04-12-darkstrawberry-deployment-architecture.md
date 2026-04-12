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

**Important constraint**: The portal is a single Vite build — all apps are code-split chunks in one SPA deployed to one Firebase Hosting site. You cannot deploy Read Tracker's frontend independently of Portfolio Tracker's at the hosting level. However, each app can have its own **release workflow** that triggers independently, runs the full portal build, and tags the release with that app's version.

## Workflow Architecture

### Overview

```
PR opened/updated
  |
  +--> [portal-test]      Unit + E2E tests (if any portal paths changed)
  +--> [portal-preview]   Preview channel deploy (if any portal paths changed)
  +--> [functions-test]   Lint + build check (if functions paths changed)
  +--> [rules-validate]   firebase rules validate (if rules changed)
  |
  All checks pass -> merge to main
  |
  +--> [app-release: read-tracker]       If apps/myApps/read-tracker/** changed
  +--> [app-release: portfolio-tracker]  If apps/myApps/portfolio-tracker/** changed
  +--> [app-release: task-list]          If apps/myApps/task-list/** changed
  +--> [app-release: bee]                If apps/yourApps/bee/** changed
  +--> [platform-release]                If apps/myapps/**, apps/platform/**, apps/shared/** changed
  |
  |  (Each release: build portal -> staging -> approval -> production -> tag)
  |
  +--> [landing-deploy]    If apps/landing/** changed
  +--> [functions-deploy]  If apps/functions/** changed
  +--> [rules-deploy]      If apps/myapps/(firestore|storage).rules changed
```

### Design: Per-App Release via Reusable Workflow

Since every app release requires a full portal build (single SPA), the build/staging/production pipeline is identical across apps. We use a **reusable workflow** to avoid duplication: one shared build-stage-deploy pipeline, called by per-app trigger workflows.

#### Reusable Workflow: `.github/workflows/portal-build-deploy.yml`

```yaml
name: Portal — Build & Deploy (reusable)

on:
  workflow_call:
    inputs:
      app_name:
        description: 'App being released (e.g. read-tracker, bee, platform)'
        required: true
        type: string
      app_version:
        description: 'App version from manifest (e.g. 1.3.0)'
        required: true
        type: string

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
    environment: staging
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
      - name: Notify Discord — staging ready
        env:
          DISCORD_RELAY_WEBHOOK_URL: ${{ secrets.DISCORD_RELAY_WEBHOOK_URL }}
          DISCORD_RELAY_WEBHOOK_SECRET: ${{ secrets.DISCORD_RELAY_WEBHOOK_SECRET }}
          STAGING_URL: ${{ steps.staging_deploy.outputs.details_url }}
          APP_NAME: ${{ inputs.app_name }}
          APP_VERSION: ${{ inputs.app_version }}
          COMMIT_MESSAGE: ${{ github.event.head_commit.message }}
        run: echo "[$APP_NAME v$APP_VERSION] Staging deployed: $STAGING_URL"

  production:
    needs: staging
    runs-on: ubuntu-latest
    environment: production
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
          APP_NAME: ${{ inputs.app_name }}
          APP_VERSION: ${{ inputs.app_version }}
          COMMIT_MESSAGE: ${{ github.event.head_commit.message }}
          REPO: ${{ github.repository }}
        run: node .github/scripts/notify-discord-shipped.js
      - name: Tag release
        run: |
          TAG="${{ inputs.app_name }}-v${{ inputs.app_version }}"
          DEPLOY_TAG="deploy-portal-$(date +%Y%m%d)-$(echo ${{ github.sha }} | cut -c1-7)"
          git tag "$TAG" || echo "Tag $TAG already exists, skipping"
          git tag "$DEPLOY_TAG"
          git push origin "$TAG" "$DEPLOY_TAG" 2>/dev/null || true
```

#### Per-App Trigger Workflows

Each app gets a thin trigger workflow that detects changes, reads the app version from its manifest, and calls the reusable workflow.

**`app-release-read-tracker.yml`** (example — one per app):

```yaml
name: Release — Read Tracker

on:
  push:
    branches: [main]
    paths:
      - 'apps/myApps/read-tracker/**'

jobs:
  get-version:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
    steps:
      - uses: actions/checkout@v4
      - name: Extract version from manifest
        id: version
        run: |
          VERSION=$(node -e "const m = require('./apps/myApps/read-tracker/index.ts'); console.log(m.version || '0.0.0')" 2>/dev/null \
            || grep -oP "version:\s*['\"]?\K[0-9]+\.[0-9]+\.[0-9]+" apps/myApps/read-tracker/index.ts \
            || echo "0.0.0")
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"

  release:
    needs: get-version
    uses: ./.github/workflows/portal-build-deploy.yml
    with:
      app_name: read-tracker
      app_version: ${{ needs.get-version.outputs.version }}
    secrets: inherit
```

**Complete list of per-app workflows:**

| Workflow | Path Trigger | App Name |
|----------|-------------|----------|
| `app-release-read-tracker.yml` | `apps/myApps/read-tracker/**` | `read-tracker` |
| `app-release-portfolio-tracker.yml` | `apps/myApps/portfolio-tracker/**` | `portfolio-tracker` |
| `app-release-task-list.yml` | `apps/myApps/task-list/**` | `task-list` |
| `app-release-bee.yml` | `apps/yourApps/bee/**` | `bee` |
| `platform-release.yml` | `apps/myapps/**`, `apps/platform/**`, `apps/shared/**` | `platform` |

New apps get a new trigger workflow when created. The trigger workflow is a ~25 line file — trivial to scaffold.

#### Concurrency Control

Multiple app changes in one commit (e.g. shared component update) could trigger multiple release workflows simultaneously. Each would build and deploy the same portal — wasteful but safe (last one wins, all contain the same code). To avoid this:

```yaml
# Add to each per-app trigger workflow
concurrency:
  group: portal-deploy
  cancel-in-progress: false    # Don't cancel — queue instead
```

This serializes portal deploys. If Read Tracker and Bee both trigger, one waits for the other. Both tag independently with their own app version.

#### Shared/Platform Changes

Changes to `apps/shared/` or `apps/platform/` affect all apps but don't belong to any single app. The `platform-release.yml` workflow handles these. It uses `app_name: platform` and reads the version from `apps/myapps/package.json`.

If a commit touches both `apps/shared/` and `apps/myApps/read-tracker/`, both `platform-release.yml` and `app-release-read-tracker.yml` fire. The concurrency group serializes them. Both deploys contain the same code. Each tags independently.

### Per-App Release Tags

Two tags per production deploy:

1. **App version tag**: `{app-name}-v{semver}` — e.g. `read-tracker-v2.1.0`, `bee-v1.0.3`, `platform-v1.1.0`
2. **Deploy tag**: `deploy-portal-{YYYYMMDD}-{short-sha}` — infra-level, same as before

App version tags are the user-facing release identifier. Deploy tags track the actual deployment event. A single deploy tag may correspond to multiple app version tags if multiple apps released in the same commit.

### Non-Portal Workflows (unchanged from previous design)

#### Landing Page Deploy (`landing-deploy.yml`)

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

#### Cloud Functions Deploy (`functions-deploy.yml`)

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

#### Firestore & Storage Rules Deploy (`rules-deploy.yml`)

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
    environment: production
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

#### PR Validation: Rules (`rules-validate.yml`)

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

#### PR Validation: Functions (`functions-test.yml`)

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

Two layers of versioning: **per-app versions** (user-facing, semver) and **deploy tags** (infrastructure, date-based).

### Per-App Versions (Semver)

Each app has its own independent version number, stored in its manifest file (`index.ts`):

```
apps/myApps/read-tracker/index.ts      -> version: "1.3.0"
apps/myApps/portfolio-tracker/index.ts  -> version: "1.1.2"
apps/myApps/task-list/index.ts          -> version: "0.9.0"
apps/yourApps/bee/index.ts              -> version: "2.0.1"
```

Format: **semver** (`major.minor.patch`). Bumped manually by the developer when making changes to that specific app. The version is:
- Displayed in the app's UI (e.g. footer or settings page)
- Stored in the Firestore app registry (`/apps/{appId}.version`)
- Included in the portal's build output for debugging (`window.__DS_APP_VERSIONS__`)

**When to bump:**
- `patch` — bug fixes, minor tweaks
- `minor` — new features, UX improvements
- `major` — breaking changes, data migrations, major redesigns

The platform shell itself also has a version in `apps/myapps/package.json` (the existing `"version": "1.0.1"`), bumped when platform-level changes ship (auth, routing, shared components).

### Deploy Tags (Infrastructure)

**Git tags** track what code is deployed. Format: `deploy-{target}-{YYYYMMDD}-{short-sha}`.

Examples:
```
deploy-portal-20260412-abc1234
deploy-landing-20260412-def5678
deploy-functions-20260412-ghi9012
deploy-rules-20260412-jkl3456
```

Tags are created automatically by the production deploy jobs. Per-app release workflows also create app version tags:
```
read-tracker-v2.1.0
bee-v1.0.3
platform-v1.1.0
```

This gives:
- Per-app release history: `git tag -l 'read-tracker-v*'` shows all Read Tracker releases
- Deploy-level tracking: `git diff deploy-portal-20260411-xxx deploy-portal-20260412-yyy`
- Rollback targets at both levels

Deploy tags are orthogonal to app versions — a single portal deploy may include version bumps for multiple apps, or none at all (e.g. a platform-only change).

## Rollback Plan

### Portal Rollback

Firebase Hosting keeps the last several deploys. Rollback options:

1. **Firebase Console** — one-click rollback to any previous deploy in the Firebase Hosting console. Fastest option (< 1 minute).
2. **Redeploy a tag** — trigger a manual workflow run that checks out a specific tag and deploys. Add `workflow_dispatch` to the reusable workflow:

```yaml
# Manual trigger on portal-build-deploy.yml
on:
  workflow_dispatch:
    inputs:
      tag:
        description: 'Git tag to deploy (e.g. read-tracker-v2.0.0 or deploy-portal-20260411-abc1234)'
        required: true
      app_name:
        description: 'App name for tagging'
        required: true
      app_version:
        description: 'App version for tagging'
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

### PR Workflows (validation gates)

| Workflow | Trigger | Path Filter |
|----------|---------|-------------|
| `portal-test.yml` | PR | `apps/(myapps\|platform\|shared\|myApps\|yourApps)/` |
| `portal-preview.yml` | PR | `apps/(myapps\|platform\|shared\|myApps\|yourApps)/` |
| `functions-test.yml` | PR | `apps/functions/` |
| `rules-validate.yml` | PR | `apps/myapps/(firestore\|storage).rules` |

### Per-App Release Workflows (push to main)

| Workflow | Path Filter | App Name | Tags Created |
|----------|-------------|----------|-------------|
| `app-release-read-tracker.yml` | `apps/myApps/read-tracker/**` | `read-tracker` | `read-tracker-v{x.y.z}` + deploy tag |
| `app-release-portfolio-tracker.yml` | `apps/myApps/portfolio-tracker/**` | `portfolio-tracker` | `portfolio-tracker-v{x.y.z}` + deploy tag |
| `app-release-task-list.yml` | `apps/myApps/task-list/**` | `task-list` | `task-list-v{x.y.z}` + deploy tag |
| `app-release-bee.yml` | `apps/yourApps/bee/**` | `bee` | `bee-v{x.y.z}` + deploy tag |
| `platform-release.yml` | `apps/myapps/**`, `apps/platform/**`, `apps/shared/**` | `platform` | `platform-v{x.y.z}` + deploy tag |

### Infrastructure Workflows (push to main)

| Workflow | Path Filter | Environment Gate |
|----------|-------------|------------------|
| `landing-deploy.yml` | `apps/landing/` | none |
| `functions-deploy.yml` | `apps/functions/` | none |
| `rules-deploy.yml` | `apps/myapps/(firestore\|storage).rules` | production |

### Reusable Workflow

| Workflow | Called By | Purpose |
|----------|----------|---------|
| `portal-build-deploy.yml` | All per-app release workflows | Build portal, stage, approve, deploy, tag |

**Total: 13 workflow files** (4 PR gates + 5 per-app releases + 3 infra deploys + 1 reusable)

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
