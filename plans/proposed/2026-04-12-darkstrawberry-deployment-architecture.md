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

## Monorepo Build Model — Turborepo + Workspaces

### Why Turborepo

The previous design used GitHub Actions path filters to trigger per-app workflows — fragile, no dependency awareness, and no caching. Turborepo solves this properly:

- **Dependency graph**: Turborepo understands which packages depend on which. A change to `@ds/shared` automatically rebuilds everything that imports it.
- **Affected-only execution**: `turbo run build --filter=...[HEAD~1]` only builds packages that changed since the last commit.
- **Remote caching**: Build artifacts cached across CI runs. If `@ds/read-tracker` hasn't changed, its build is instant.
- **Task orchestration**: `build`, `test`, `lint`, `deploy` are all Turborepo pipelines that respect dependency order.

### Workspace Structure

Each directory under `apps/` becomes an npm workspace with its own `package.json`:

```
package.json              # Root — workspaces config, turbo as devDependency
turbo.json                # Pipeline definitions
apps/
  portal/                 # @ds/portal — Vite root, app shell, router
    package.json          # depends on @ds/platform, @ds/shared, @ds/read-tracker, etc.
  platform/               # @ds/platform — nav, auth, app loader
    package.json          # depends on @ds/shared
  shared/                 # @ds/shared — Firebase helpers, types, UI components
    package.json
  myApps/
    read-tracker/         # @ds/read-tracker
      package.json        # depends on @ds/shared
    portfolio-tracker/    # @ds/portfolio-tracker
      package.json        # depends on @ds/shared
    task-list/            # @ds/task-list
      package.json        # depends on @ds/shared
  yourApps/
    bee/                  # @ds/bee
      package.json        # depends on @ds/shared
  functions/              # @ds/functions — Cloud Functions (separate deploy target)
    package.json
  landing/                # @ds/landing — static HTML (separate deploy target)
    package.json
```

The `@ds/portal` package is the Vite build root. It depends on all app packages. Vite aliases resolve workspace paths. The final build produces a single SPA in `apps/portal/dist/`.

### turbo.json

```json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": [".env"],
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"],
      "cache": true
    },
    "test": {
      "dependsOn": ["build"],
      "cache": true
    },
    "lint": {
      "cache": true
    },
    "deploy:portal": {
      "dependsOn": ["build"],
      "cache": false
    },
    "deploy:functions": {
      "dependsOn": ["build"],
      "cache": false
    },
    "deploy:landing": {
      "cache": false
    },
    "deploy:rules": {
      "cache": false
    }
  }
}
```

### Key Constraint

The portal is a single Vite build — all apps are code-split chunks in one SPA deployed to one Firebase Hosting site. Turborepo's dependency graph determines **which apps are affected** and triggers the appropriate test/build/deploy pipeline. But the portal deploy always deploys the entire SPA.

## Workflow Architecture — Turborepo-Driven

### Overview

Turborepo replaces path-based GitHub Actions triggers. Instead of N per-app workflow files, we have **3 core workflows** that use `turbo run --filter` to determine what's affected and act accordingly.

```
PR opened/updated
  |
  +--> [ci.yml]  turbo run lint test build --filter=...[origin/main]
  |              (only affected packages — cached results for unchanged)
  |
  +--> [preview.yml]  If portal affected: build + Firebase preview channel deploy
  |
  All checks pass -> merge to main
  |
  +--> [release.yml]
        |
        +-- turbo run build --filter=...[HEAD~1]
        +-- Changesets: version bumps + changelog + git tags
        +-- Determine affected deploy targets (portal? functions? landing? rules?)
        +-- For each affected target:
              staging -> approval -> production -> Discord notification
```

### 1. CI Pipeline (`ci.yml`)

Runs on every PR. Turborepo handles affected-only execution.

```yaml
name: CI

on:
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci

      - name: Lint affected packages
        run: npx turbo run lint --filter=...[origin/main]

      - name: Test affected packages
        run: npx turbo run test --filter=...[origin/main]
        env: { ... VITE_FIREBASE_* secrets ... }

      - name: Build affected packages
        run: npx turbo run build --filter=...[origin/main]
        env: { ... VITE_FIREBASE_* secrets ... }

      - name: Validate Firestore rules (if changed)
        run: |
          if git diff --name-only origin/main...HEAD | grep -q 'firestore.rules\|storage.rules'; then
            npx firebase-tools@latest firestore:rules:validate apps/portal/firestore.rules \
              --project ${{ vars.FIREBASE_PROJECT_ID }}
          fi
        env:
          GOOGLE_APPLICATION_CREDENTIALS: /tmp/sa.json

      - name: E2E tests (if portal affected)
        run: |
          if npx turbo run build --filter=@ds/portal --dry-run=json | grep -q '"@ds/portal"'; then
            cd apps/portal && npx playwright test --project=chromium
          fi
        env: { ... VITE_FIREBASE_* secrets ... }
```

Turborepo's `--filter=...[origin/main]` computes the dependency graph diff: if `@ds/shared` changed, all packages depending on it (every app) get linted/tested/built. If only `@ds/read-tracker` changed, only it and `@ds/portal` (which depends on it) are affected. Unchanged packages use cached results.

### 2. Preview Deploy (`preview.yml`)

```yaml
name: Preview

on:
  pull_request:
    branches: [main]

jobs:
  preview:
    if: github.event.pull_request.head.repo.full_name == github.repository
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci

      - name: Check if portal is affected
        id: check
        run: |
          AFFECTED=$(npx turbo run build --filter=@ds/portal...[origin/main] --dry-run=json 2>/dev/null)
          if echo "$AFFECTED" | grep -q '"@ds/portal"'; then
            echo "portal_affected=true" >> "$GITHUB_OUTPUT"
          else
            echo "portal_affected=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Build portal
        if: steps.check.outputs.portal_affected == 'true'
        run: npx turbo run build --filter=@ds/portal
        env: { ... VITE_FIREBASE_* secrets ... }

      - name: Deploy preview
        if: steps.check.outputs.portal_affected == 'true'
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          projectId: ${{ vars.FIREBASE_PROJECT_ID }}
          channelId: pr-${{ github.event.number }}
          entryPoint: apps/portal
          expires: 7d
```

### 3. Release Pipeline (`release.yml`)

The main deploy workflow. Runs on push to main. Uses Changesets for versioning and Turborepo for affected-only builds.

```yaml
name: Release

on:
  push:
    branches: [main]

concurrency:
  group: release
  cancel-in-progress: false

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci

      # --- Changesets: version + changelog + tags ---
      - name: Create release PR or publish
        id: changesets
        uses: changesets/action@v1
        with:
          publish: npx changeset tag
          version: npx changeset version
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      # --- Determine affected deploy targets ---
      - name: Detect affected targets
        id: targets
        run: |
          AFFECTED=$(npx turbo run build --filter=...[HEAD~1] --dry-run=json)

          echo "portal=false" >> "$GITHUB_OUTPUT"
          echo "functions=false" >> "$GITHUB_OUTPUT"
          echo "landing=false" >> "$GITHUB_OUTPUT"
          echo "rules=false" >> "$GITHUB_OUTPUT"

          echo "$AFFECTED" | grep -q '"@ds/portal"'              && echo "portal=true" >> "$GITHUB_OUTPUT"
          echo "$AFFECTED" | grep -q '"@ds/functions"'           && echo "functions=true" >> "$GITHUB_OUTPUT"
          echo "$AFFECTED" | grep -q '"@ds/landing"'             && echo "landing=true" >> "$GITHUB_OUTPUT"
          git diff --name-only HEAD~1 | grep -q 'firestore.rules\|storage.rules' && echo "rules=true" >> "$GITHUB_OUTPUT"

          # Collect affected app names for Discord notification
          APPS=""
          echo "$AFFECTED" | grep -oP '"@ds/\K[^"]+' | while read pkg; do
            APPS="$APPS $pkg"
          done
          echo "affected_apps=$APPS" >> "$GITHUB_OUTPUT"

      # --- Build affected packages ---
      - name: Build
        run: npx turbo run build --filter=...[HEAD~1]
        env: { ... VITE_FIREBASE_* secrets ... }

      - uses: actions/upload-artifact@v4
        if: steps.targets.outputs.portal == 'true'
        with: { name: portal-dist, path: apps/portal/dist/ }

  # --- Portal: staging -> production ---
  portal-staging:
    needs: release
    if: needs.release.outputs.portal == 'true'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with: { name: portal-dist, path: apps/portal/dist/ }
      - uses: FirebaseExtended/action-hosting-deploy@v0
        id: staging
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          projectId: ${{ vars.FIREBASE_PROJECT_ID }}
          channelId: staging
          entryPoint: apps/portal
          expires: 7d
      - name: Notify Discord — staging
        run: echo "Portal staging deployed — ${{ steps.staging.outputs.details_url }}"

  portal-production:
    needs: portal-staging
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with: { name: portal-dist, path: apps/portal/dist/ }
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          channelId: live
          projectId: ${{ vars.FIREBASE_PROJECT_ID }}
          entryPoint: apps/portal
      - name: Tag deploy
        run: |
          TAG="deploy-portal-$(date +%Y%m%d)-$(echo ${{ github.sha }} | cut -c1-7)"
          git tag "$TAG" && git push origin "$TAG"
      - name: Notify Discord — shipped
        run: node .github/scripts/notify-discord-shipped.js

  # --- Functions deploy ---
  functions-deploy:
    needs: release
    if: needs.release.outputs.functions == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npx turbo run build --filter=@ds/functions
      - name: Deploy functions
        run: |
          echo "${{ secrets.FIREBASE_SERVICE_ACCOUNT }}" > /tmp/sa.json
          GOOGLE_APPLICATION_CREDENTIALS=/tmp/sa.json \
            npx firebase-tools@latest deploy --only functions \
            --project ${{ vars.FIREBASE_PROJECT_ID }} --non-interactive

  # --- Landing deploy ---
  landing-deploy:
    needs: release
    if: needs.release.outputs.landing == 'true'
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

  # --- Rules deploy ---
  rules-deploy:
    needs: release
    if: needs.release.outputs.rules == 'true'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - name: Deploy rules
        run: |
          echo "${{ secrets.FIREBASE_SERVICE_ACCOUNT }}" > /tmp/sa.json
          GOOGLE_APPLICATION_CREDENTIALS=/tmp/sa.json \
            npx firebase-tools@latest deploy --only firestore:rules,storage \
            --project ${{ vars.FIREBASE_PROJECT_ID }} --non-interactive
        working-directory: apps/portal
```

## Versioning Strategy — Changesets

### Why Changesets

[Changesets](https://github.com/changesets/changesets) is the standard versioning tool for monorepos. It handles:
- **Per-package semver** — each workspace has its own version in its `package.json`
- **Changelogs** — auto-generated per package from changeset descriptions
- **Dependency-aware bumps** — if `@ds/shared` gets a minor bump, all packages depending on it get a patch bump automatically
- **Git tags** — `@ds/read-tracker@2.1.0` style tags on release

### Workflow

1. **Developer makes changes** to `@ds/read-tracker`
2. **Developer runs `npx changeset`** — selects the affected package(s), chooses bump type (patch/minor/major), writes a one-line description
3. This creates a `.changeset/fuzzy-dogs-dance.md` file (committed with the PR)
4. **PR merges to main** — the release workflow runs `changeset version` which:
   - Bumps `package.json` versions in affected packages
   - Updates `CHANGELOG.md` in each affected package
   - Bumps dependents (if `@ds/shared` bumped, `@ds/read-tracker` etc. get a patch bump)
5. **`changeset tag`** creates git tags: `@ds/read-tracker@2.1.0`, `@ds/bee@1.0.3`, etc.
6. **Deploy pipeline** runs for affected packages

### Version Storage

Each app's version lives in its workspace `package.json`:

```json
// apps/myApps/read-tracker/package.json
{ "name": "@ds/read-tracker", "version": "2.1.0", ... }

// apps/yourApps/bee/package.json
{ "name": "@ds/bee", "version": "1.0.3", ... }

// apps/portal/package.json
{ "name": "@ds/portal", "version": "1.2.0", ... }
```

The version is also:
- Displayed in the app's UI (footer or settings page) — read from `package.json` at build time via Vite's `define`
- Stored in the Firestore app registry (`/apps/{appId}.version`) — updated by a post-deploy step
- Included in the portal's build output for debugging (`window.__DS_APP_VERSIONS__`)

### Deploy Tags

In addition to Changesets' `@ds/read-tracker@2.1.0` tags, the deploy pipeline creates infrastructure tags:

```
deploy-portal-20260412-abc1234
deploy-functions-20260412-def5678
```

These track the actual deployment event (what code was deployed when), orthogonal to app versions.

### Changeset Example

```markdown
---
"@ds/read-tracker": minor
---

Add reading goal streaks — users can now see their consecutive days of reading
```

If the change also touched `@ds/shared`:

```markdown
---
"@ds/shared": patch
"@ds/read-tracker": minor
---

Add streak calculation helper to shared utils; implement reading goal streaks UI
```

Changesets auto-bumps all dependents of `@ds/shared` with a patch release.

## Rollback Plan

### Portal Rollback

Firebase Hosting keeps the last several deploys. Rollback options:

1. **Firebase Console** — one-click rollback to any previous deploy in the Firebase Hosting console. Fastest option (< 1 minute).
2. **Redeploy a tag** — trigger the release workflow manually via `workflow_dispatch`, checking out a known-good tag:

```yaml
# Add to release.yml
on:
  workflow_dispatch:
    inputs:
      ref:
        description: 'Git ref to deploy (tag or SHA, e.g. @ds/read-tracker@2.0.0 or deploy-portal-20260411-abc1234)'
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

| Workflow | Trigger | What It Does |
|----------|---------|-------------|
| `ci.yml` | PR | `turbo run lint test build --filter=...[origin/main]` + rules validation + E2E if portal affected |
| `preview.yml` | PR | Build + Firebase preview channel deploy (if portal affected) |
| `release.yml` | push to main | Changesets version/tag + `turbo run build --filter=...[HEAD~1]` + deploy affected targets (portal staging->prod, functions, landing, rules) |

**Total: 3 workflow files.** Down from 13 in the previous design. Turborepo's dependency graph replaces per-app path filters. Changesets replaces manual version management.

### Adding a New App

1. Create workspace: `apps/myApps/new-app/package.json` with `"name": "@ds/new-app"`
2. Add dependency in `apps/portal/package.json`: `"@ds/new-app": "workspace:*"`
3. Run `npx changeset` when making changes — Changesets handles versioning
4. No new workflow files needed — Turborepo automatically includes it in the dependency graph

## New Dependencies

| Package | Purpose | Dev/Prod |
|---------|---------|----------|
| `turbo` | Monorepo build orchestrator | devDependency (root) |
| `@changesets/cli` | Per-package versioning + changelogs | devDependency (root) |
| `@changesets/changelog-github` | GitHub-linked changelog entries | devDependency (root) |

## Migration Steps

### Phase 1: Turborepo setup
1. Add root `package.json` with `workspaces` config pointing to all `apps/` directories
2. Add `package.json` to each app directory that doesn't have one (platform, shared, each myApp, each yourApp)
3. Install `turbo` and configure `turbo.json` pipeline
4. Migrate Vite aliases to workspace resolution (`@ds/shared` instead of `../shared`)
5. Verify `turbo run build` works locally

### Phase 2: Changesets setup
1. `npx changeset init` — creates `.changeset/` config directory
2. Configure `@changesets/changelog-github` for GitHub-linked changelogs
3. Add initial versions to all workspace `package.json` files

### Phase 3: CI migration
1. Create `staging` and `production` GitHub Environments in repo settings
2. Add Duong as required reviewer for `production` environment
3. Create `ci.yml`, `preview.yml`, `release.yml`
4. Delete old workflows: `myapps-prod-deploy.yml`, `myapps-pr-preview.yml`, `myapps-test.yml`, `landing-prod-deploy.yml`
5. Enable Turborepo Remote Caching (optional, via Vercel — free for small teams)

### Phase 4: Verify
1. Test with a PR that touches only one app — verify only that app's tests run
2. Test with a PR that touches `@ds/shared` — verify all dependents are tested
3. Test merge to main — verify Changesets creates version PR, deploy pipeline runs
4. Verify rollback via `workflow_dispatch`

## Open Questions

None. This plan is self-contained and ready for implementation.
