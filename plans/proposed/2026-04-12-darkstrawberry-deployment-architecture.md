---
title: Dark Strawberry — Deployment Architecture
status: proposed
owner: swain
date: 2026-04-12
tags: [architecture, deployment, ci-cd, darkstrawberry]
---

# Dark Strawberry — Deployment Architecture

## Core Decision: Independent Deployables

Each app is its own standalone Vue 3 + Vite mini-app with its own build, its own Firebase Hosting site, and its own deploy pipeline. The platform portal is a separate deployable that serves as a launcher/catalog linking to individual apps.

**Deploying Read Tracker v2.1.0 does NOT rebuild, redeploy, or touch Portfolio Tracker in any way.**

This is not micro-frontends. No runtime composition, no module federation. Each app is a fully independent SPA sharing a design system and Firebase project. Users navigate between apps via standard links with a full page load when switching apps.

## Hosting: Single Site, Composite Deploy

All apps live on one Firebase Hosting site (`apps.darkstrawberry.com`) under path prefixes. Each app builds independently with Vite's `base` set to its path prefix. A composite deploy script assembles all app dists into one directory structure and deploys to Firebase Hosting.

### URL Structure

```
apps.darkstrawberry.com/                              # Portal (launcher, catalog, settings)
apps.darkstrawberry.com/myApps/read-tracker/           # Read Tracker
apps.darkstrawberry.com/myApps/read-tracker/dashboard
apps.darkstrawberry.com/myApps/portfolio-tracker/       # Portfolio Tracker
apps.darkstrawberry.com/myApps/task-list/               # Task List
apps.darkstrawberry.com/yourApps/bee/                   # Bee
darkstrawberry.com                                      # Landing page (separate site)
```

### How It Works

Each app builds with Vite's `base` option set to its path prefix:

```typescript
// apps/myApps/read-tracker/vite.config.ts
export default defineConfig({
  base: '/myApps/read-tracker/',
  // ...
})
```

This makes all asset URLs relative to the prefix. The app's `dist/` contains files that expect to be served from `/myApps/read-tracker/`.

**Composite deploy directory:**
```
deploy/                                    # Assembled before deploy
  index.html                               # Portal
  assets/                                  # Portal assets
  myApps/
    read-tracker/
      index.html                           # Read Tracker SPA entry
      assets/                              # Read Tracker assets
    portfolio-tracker/
      index.html
      assets/
    task-list/
      index.html
      assets/
  yourApps/
    bee/
      index.html
      assets/
```

**`scripts/composite-deploy.sh`** assembles this directory:
```bash
#!/usr/bin/env bash
# Assembles all app dists into a single deploy directory
set -euo pipefail
DEPLOY_DIR="deploy"
rm -rf "$DEPLOY_DIR"

# Portal at root
cp -r apps/portal/dist/* "$DEPLOY_DIR/"

# Each app under its path prefix
for app in apps/myApps/*/; do
  SLUG=$(basename "$app")
  [ -d "$app/dist" ] && mkdir -p "$DEPLOY_DIR/myApps/$SLUG" && cp -r "$app/dist/"* "$DEPLOY_DIR/myApps/$SLUG/"
done
for app in apps/yourApps/*/; do
  SLUG=$(basename "$app")
  [ -d "$app/dist" ] && mkdir -p "$DEPLOY_DIR/yourApps/$SLUG" && cp -r "$app/dist/"* "$DEPLOY_DIR/yourApps/$SLUG/"
done
```

### Firebase Hosting Config

One site, one `firebase.json` at repo root:

```json
{
  "hosting": {
    "public": "deploy",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      { "source": "/myApps/read-tracker/**", "destination": "/myApps/read-tracker/index.html" },
      { "source": "/myApps/portfolio-tracker/**", "destination": "/myApps/portfolio-tracker/index.html" },
      { "source": "/myApps/task-list/**", "destination": "/myApps/task-list/index.html" },
      { "source": "/yourApps/bee/**", "destination": "/yourApps/bee/index.html" },
      { "source": "**", "destination": "/index.html" }
    ],
    "headers": [
      { "source": "**/*.@(js|css)", "headers": [{ "key": "Cache-Control", "value": "max-age=31536000" }] },
      { "source": "**/*.@(jpg|jpeg|gif|png|svg|webp|ico)", "headers": [{ "key": "Cache-Control", "value": "max-age=31536000" }] },
      { "source": "**", "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "DENY" }
      ]}
    ]
  },
  "firestore": { "rules": "apps/portal/firestore.rules" },
  "storage": { "rules": "apps/portal/storage.rules" }
}
```

Each app's route prefix gets a rewrite to its own `index.html` — standard SPA routing. New app = add one rewrite line.

### Landing Page

Separate Firebase Hosting site (`ds-landing`) at `darkstrawberry.com`. Independent deploy. Unchanged from current setup.

### Independent Builds, Composite Deploy

Each app builds independently (own Vite config, own `package.json`). The deploy step composites all dists and uploads once. **The key insight:** even though the deploy uploads the full composite directory, only the **changed app was rebuilt**. Unchanged apps' dists are cached by Turborepo — the composite step just copies their existing cached output. Firebase Hosting's content-addressable storage deduplicates unchanged files, so uploading the full composite is fast even when only one app changed.

### Auth

All apps share the same origin (`apps.darkstrawberry.com`), so Firebase Auth tokens are shared automatically. No cross-origin auth flow needed. Users sign in once and are authenticated across all apps. This is simpler than the subdomain approach.

### Sites Summary

| Site | Domain | Purpose |
|------|--------|---------|
| default (portal) | `apps.darkstrawberry.com` | Portal + all apps (composite deploy) |
| `ds-landing` | `darkstrawberry.com` | Landing page |

## Monorepo Structure

```
package.json                          # Root workspaces
turbo.json                            # Turborepo pipeline config
.changeset/                           # Changesets config
scripts/
  scaffold-app.sh                     # Scaffold new app from template
apps/
  portal/                             # @ds/portal — launcher, catalog, settings
    package.json, vite.config.ts, src/
  landing/                            # @ds/landing — marketing page (separate Firebase site)
    package.json, firebase.json
  shared/                             # @ds/shared — design system, Firebase helpers, types
    package.json, src/
  myApps/
    read-tracker/                     # @ds/read-tracker — standalone Vue app
      package.json, vite.config.ts, src/, CHANGELOG.md
    portfolio-tracker/                # @ds/portfolio-tracker
      package.json, vite.config.ts, src/, CHANGELOG.md
    task-list/                        # @ds/task-list
      package.json, vite.config.ts, src/, CHANGELOG.md
  yourApps/
    bee/                              # @ds/bee
      package.json, vite.config.ts, src/, CHANGELOG.md
  functions/                          # @ds/functions — Cloud Functions
    package.json
  deploy/                             # Composite deploy dir (gitignored, assembled at deploy time)
```

Each app is self-contained: own `package.json` (own dependencies, own version), own `vite.config.ts` (with `base` set to its path prefix), own `src/`, own `CHANGELOG.md`. Apps import `@ds/shared` via workspace dependency. No per-app `firebase.json` — one root `firebase.json` handles all routing.

`@ds/shared` contains Firebase init/auth, Firestore helpers, design system (Vue components, Tailwind preset), platform types. It's a build-time dependency only — never deployed directly.

### Turborepo

Turborepo orchestrates builds, tests, and linting across workspaces with dependency-aware affected detection and caching.

**`turbo.json`:**
```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "test": {
      "dependsOn": ["^build"]
    },
    "test:run": {
      "dependsOn": ["^build"]
    },
    "lint": {},
    "test:e2e": {
      "dependsOn": ["build"],
      "cache": false
    }
  }
}
```

**Key commands:**
- `turbo run build --filter=...[origin/main]` — build only packages affected since main (walks dependency graph: if `@ds/shared` changed, all dependents rebuild)
- `turbo run build --filter=@ds/read-tracker` — build one app + its dependencies
- `turbo run test --filter=...[HEAD~1]` — test only packages affected by the last commit
- `turbo run build --dry-run=json --filter=...[HEAD~1]` — list affected packages without building (used to compute the deploy matrix)

## Deployment Pipeline

### Overview

```
PR
  +--> [ci.yml]       turbo run lint test build --filter=...[origin/main]
  |                   + E2E per affected app + rules validation
  +--> [preview.yml]  Build affected apps -> composite -> Firebase preview channel

Merge to main
  +--> [release.yml]  Changesets version/tag
                      -> turbo run build (affected apps, cached for unchanged)
                      -> composite-deploy.sh (assemble all dists into deploy/)
                      -> Firebase Hosting deploy (single site)
                      -> tag affected apps
                      + functions deploy + rules deploy + Discord notification
```

### Release Workflow (`release.yml`)

Builds only affected apps (Turborepo caches unchanged ones), composites all dists, deploys the whole site once.

```yaml
name: Release
on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      ref: { description: 'Git ref for rollback', required: false }

concurrency: { group: release, cancel-in-progress: false }

jobs:
  deploy-portal:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0, ref: '${{ github.event.inputs.ref || github.sha }}' }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci

      # Changesets: bump versions, changelogs, tags
      - name: Version packages
        if: github.event_name == 'push'
        run: |
          npx changeset version && npx changeset tag
          git add -A && git diff --cached --quiet || git commit -m "chore: version packages"
          git push --follow-tags
        env: { GITHUB_TOKEN: '${{ secrets.GITHUB_TOKEN }}' }

      # Build all apps — Turborepo caches unchanged ones
      - name: Build all apps
        run: npx turbo run build
        env:
          VITE_FIREBASE_API_KEY: ${{ secrets.VITE_FIREBASE_API_KEY }}
          VITE_FIREBASE_AUTH_DOMAIN: ${{ secrets.VITE_FIREBASE_AUTH_DOMAIN }}
          VITE_FIREBASE_PROJECT_ID: ${{ secrets.VITE_FIREBASE_PROJECT_ID }}
          VITE_FIREBASE_STORAGE_BUCKET: ${{ secrets.VITE_FIREBASE_STORAGE_BUCKET }}
          VITE_FIREBASE_MESSAGING_SENDER_ID: ${{ secrets.VITE_FIREBASE_MESSAGING_SENDER_ID }}
          VITE_FIREBASE_APP_ID: ${{ secrets.VITE_FIREBASE_APP_ID }}
          VITE_FIREBASE_MEASUREMENT_ID: ${{ secrets.VITE_FIREBASE_MEASUREMENT_ID }}

      # Composite: assemble all dists into deploy/
      - name: Composite deploy directory
        run: bash scripts/composite-deploy.sh

      # Deploy to Firebase Hosting
      - name: Deploy
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          channelId: live
          projectId: ${{ vars.FIREBASE_PROJECT_ID }}

      # Tag affected apps
      - name: Tag releases
        run: |
          AFFECTED=$(npx turbo run build --filter=...[HEAD~1] --dry-run=json 2>/dev/null)
          PKGS=$(echo "$AFFECTED" | node -e "
            const j=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
            const pkgs=[...new Set(j.tasks.map(t=>t.package))].filter(p=>p!=='@ds/shared');
            console.log(pkgs.join(' '));
          ")
          for pkg in $PKGS; do
            SLUG=$(echo "$pkg" | sed 's/@ds\///')
            DIR=$(node -e "const ws=require('./package.json').workspaces;for(const w of ws){try{if(require('./'+(w.includes('*')?w.replace('*','')+SLUG:w)+'/package.json').name===pkg){console.log(w.includes('*')?w.replace('*','')+SLUG:w);break;}}catch(e){}}" 2>/dev/null || true)
            [ -z "$DIR" ] && continue
            VER=$(node -e "console.log(require('./$DIR/package.json').version)" 2>/dev/null || echo "0.0.0")
            git tag "${SLUG}-v${VER}" 2>/dev/null || true
          done
          DEPLOY_TAG="deploy-portal-$(date +%Y%m%d)-$(echo ${{ github.sha }} | cut -c1-7)"
          git tag "$DEPLOY_TAG"
          git push origin --tags 2>/dev/null || true

      - name: Notify Discord
        if: success()
        run: node .github/scripts/notify-discord-shipped.js
        env:
          DISCORD_RELAY_WEBHOOK_URL: ${{ secrets.DISCORD_RELAY_WEBHOOK_URL }}
          DISCORD_RELAY_WEBHOOK_SECRET: ${{ secrets.DISCORD_RELAY_WEBHOOK_SECRET }}
          COMMIT_MESSAGE: ${{ github.event.head_commit.message }}
          REPO: ${{ github.repository }}

  functions-deploy:
    runs-on: ubuntu-latest
    # Only run if functions changed
    if: contains(github.event.head_commit.modified, 'apps/functions/') || contains(github.event.head_commit.added, 'apps/functions/')
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci && npx turbo run build --filter=@ds/functions
      - run: |
          echo "${{ secrets.FIREBASE_SERVICE_ACCOUNT }}" > /tmp/sa.json
          GOOGLE_APPLICATION_CREDENTIALS=/tmp/sa.json \
            npx firebase-tools@latest deploy --only functions \
            --project ${{ vars.FIREBASE_PROJECT_ID }} --non-interactive

  rules-deploy:
    runs-on: ubuntu-latest
    environment: production
    if: contains(github.event.head_commit.modified, 'firestore.rules') || contains(github.event.head_commit.modified, 'storage.rules')
    steps:
      - uses: actions/checkout@v4
      - run: |
          echo "${{ secrets.FIREBASE_SERVICE_ACCOUNT }}" > /tmp/sa.json
          GOOGLE_APPLICATION_CREDENTIALS=/tmp/sa.json \
            npx firebase-tools@latest deploy --only firestore:rules,storage \
            --project ${{ vars.FIREBASE_PROJECT_ID }} --non-interactive
```

## Versioning — Changesets

Per-app semver in each workspace `package.json`. Agents write changeset files (markdown + YAML frontmatter):

```markdown
---
"@ds/read-tracker": minor
---
Add reading goal streaks
```

On merge: `changeset version` bumps versions + changelogs, `changeset tag` creates git tags (`@ds/read-tracker@2.1.0`). `updateInternalDependencies: "patch"` auto-patches dependents when `@ds/shared` is bumped.

Deploy tags: `deploy-{slug}-{YYYYMMDD}-{short-sha}` per app, per deploy.

## Rollback

1. **Firebase Console** — one-click rollback to any previous deploy. Rolls back the entire composite site (all apps). < 1 minute.
2. **Redeploy a tag** — `workflow_dispatch` with `ref` set to a deploy tag (e.g. `deploy-portal-20260411-abc1234`). Rebuilds all apps from that point and redeploys.
3. **Revert commit** — `git revert`, push to main, pipeline auto-rebuilds affected apps + composites + deploys.

Note: since the composite deploy uploads the full site, a rollback restores all apps to that point in time. For per-app rollback granularity, revert only the specific app's commit — Turborepo cache ensures only that app rebuilds, others serve their cached dists unchanged.

## Scaffolding New Apps

```bash
bash scripts/scaffold-app.sh my-new-app myApps
```

Creates standalone Vue app with auth, DS design system, `vite.config.ts` (with `base: '/myApps/my-new-app/'`). Add one rewrite line to root `firebase.json`. App is deployable immediately. Turborepo automatically includes it in the dependency graph.

## Summary

| | Old (single SPA) | New (independent builds, composite deploy) |
|---|---|---|
| **Build** | One Vite build for all apps | Each app builds independently (Turborepo) |
| **Deploy** | One build, one deploy | Composite: only affected apps rebuild, single deploy |
| **Blast radius** | Any change rebuilds all apps | Only affected apps rebuild (Turborepo cache) |
| **Rollback** | Rollback entire portal | Firebase Console rollback or tag redeploy |
| **Add new app** | Add routes to monolith | Scaffold standalone app + add rewrite |
| **Dependencies** | All apps share one package.json | Each app has own dependencies |
| **URL structure** | `/read-tracker/` | `/myApps/read-tracker/` |
| **Auth** | Single origin | Single origin (same domain, shared auth) |

**3 workflow files. 2 helper scripts (`composite-deploy.sh`, `scaffold-app.sh`). 3 devDependencies (Turborepo + Changesets). Single Firebase Hosting site (free tier).**

## Migration Steps

### Phase 1: Extract apps into independent builds
1. Create standalone `package.json`, `vite.config.ts` for each app (with `base` set to path prefix)
2. Move views/stores/composables from `apps/myapps/src/views/{App}/` into `apps/myApps/{app}/src/`
3. Extract shared code into `apps/shared/`
4. Verify each app builds independently: `npx turbo run build --filter=@ds/read-tracker`

### Phase 2: Turborepo + Changesets
1. Install `turbo` at root, configure `turbo.json`
2. Set up Changesets (`npx changeset init`)
3. Verify `turbo run build` builds all apps with caching

### Phase 3: Composite deploy + Firebase config
1. Write `scripts/composite-deploy.sh` and `scripts/scaffold-app.sh`
2. Create root `firebase.json` with rewrites per app
3. Verify: `bash scripts/composite-deploy.sh && firebase deploy --only hosting`

### Phase 4: CI/CD
1. Create 3 new workflows (`ci.yml`, `preview.yml`, `release.yml`)
2. Delete old workflows
3. Create `production` GitHub Environment with Duong as reviewer

### Phase 5: Portal conversion
1. Strip app code from portal — launcher/catalog only
2. Portal links to `/myApps/{slug}` and `/yourApps/{slug}` paths

## All Questions Resolved

No open questions. Path-based URLs on `apps.darkstrawberry.com` confirmed by Duong. This plan is final.
