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

## Hosting: Firebase Multi-Site

Firebase Hosting supports multiple sites per project (up to 36 on free tier). Each app gets its own site within the existing `myapps-b31ea` project.

| Site ID | Source | Domain | Purpose |
|---------|--------|--------|---------|
| `ds-portal` | `apps/portal/` | `apps.darkstrawberry.com` | Launcher, catalog, user settings |
| `ds-landing` | `apps/landing/` | `darkstrawberry.com` | Marketing landing page |
| `ds-read-tracker` | `apps/myApps/read-tracker/` | `read-tracker.darkstrawberry.com` | Read Tracker |
| `ds-portfolio-tracker` | `apps/myApps/portfolio-tracker/` | `portfolio-tracker.darkstrawberry.com` | Portfolio Tracker |
| `ds-task-list` | `apps/myApps/task-list/` | `task-list.darkstrawberry.com` | Task List |
| `ds-bee` | `apps/yourApps/bee/` | `bee.darkstrawberry.com` | Bee |

New app = new site: `firebase hosting:sites:create ds-{slug}` + DNS record for `{slug}.darkstrawberry.com`.

### URL Structure Change

The platform architecture plan specified path-based routing (`apps.darkstrawberry.com/myApps/read-tracker`). With independent deploys, each app lives on its own subdomain:

| Old (single SPA) | New (independent deploys) |
|-------------------|--------------------------|
| `apps.darkstrawberry.com/myApps/read-tracker/dashboard` | `read-tracker.darkstrawberry.com/dashboard` |
| `apps.darkstrawberry.com/yourApps/bee/home` | `bee.darkstrawberry.com/home` |
| `apps.darkstrawberry.com/` (catalog) | `apps.darkstrawberry.com/` (unchanged) |

Path-based routing on a single domain would require a reverse proxy (Cloud Functions/Cloud Run), adding latency and cost. Subdomains are zero-cost on Firebase Hosting.

**Open question:** Duong needs to confirm subdomains vs. paths.

### Auth Sharing Across Subdomains

Firebase Auth tokens are per-origin. Different subdomains = different origins. Solution: all apps use the same `authDomain`. Users sign in once on the portal. When navigating to an app subdomain, the app does a silent `signInWithRedirect` — Firebase sees the existing session and returns the token immediately (sub-second, invisible to user).

```typescript
// @ds/shared — imported by every app
const auth = getAuth(app)
export function ensureAuth(): Promise<User> {
  return new Promise((resolve) => {
    onAuthStateChanged(auth, (user) => {
      if (user) resolve(user)
      else signInWithRedirect(auth, new GoogleAuthProvider())
    })
  })
}
```

## Monorepo Structure

```
package.json                          # Root workspaces
.changeset/                           # Changesets config
scripts/
  affected.sh                         # Dependency-aware affected detection
  scaffold-app.sh                     # Scaffold new app from template
apps/
  portal/                             # @ds/portal — launcher, catalog, settings
    package.json, firebase.json, vite.config.ts, src/
  landing/                            # @ds/landing — marketing page
    package.json, firebase.json
  shared/                             # @ds/shared — design system, Firebase helpers, types
    package.json, src/
  myApps/
    read-tracker/                     # @ds/read-tracker — standalone Vue app
      package.json, firebase.json, vite.config.ts, src/, CHANGELOG.md
    portfolio-tracker/                # @ds/portfolio-tracker
      package.json, firebase.json, vite.config.ts, src/, CHANGELOG.md
    task-list/                        # @ds/task-list
      package.json, firebase.json, vite.config.ts, src/, CHANGELOG.md
  yourApps/
    bee/                              # @ds/bee
      package.json, firebase.json, vite.config.ts, src/, CHANGELOG.md
  functions/                          # @ds/functions — Cloud Functions
    package.json
```

Each app is self-contained: own `package.json` (own dependencies, own version), own `vite.config.ts`, own `firebase.json` (targets its own hosting site), own `src/`, own `CHANGELOG.md`. Apps import `@ds/shared` via workspace dependency.

`@ds/shared` contains Firebase init/auth, Firestore helpers, design system (Vue components, Tailwind preset), platform types. It's a build-time dependency only — never deployed directly.

## Deployment Pipeline

### Overview

```
PR
  +--> [ci.yml]       affected.sh -> lint/test/build per affected package + E2E per affected app
  +--> [preview.yml]  Per-app preview deploys (each app gets its own preview URL)

Merge to main
  +--> [release.yml]  Changesets version/tag -> matrix build+deploy per affected app (parallel)
                      + functions + rules + Discord notification
```

### Release Workflow (`release.yml`)

The key innovation: a **matrix strategy** that builds and deploys each affected app **in parallel**, each to its own Firebase Hosting site.

```yaml
name: Release
on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      ref: { description: 'Git ref for rollback', required: false }
      app: { description: 'Specific app to deploy (e.g. @ds/read-tracker)', required: false }

concurrency: { group: release, cancel-in-progress: false }

jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.matrix.outputs.matrix }}
      functions: ${{ steps.targets.outputs.functions }}
      rules: ${{ steps.targets.outputs.rules }}
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0, ref: '${{ github.event.inputs.ref || github.sha }}' }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci

      - name: Version packages (Changesets)
        if: github.event_name == 'push'
        run: |
          npx changeset version && npx changeset tag
          git add -A && git diff --cached --quiet || git commit -m "chore: version packages"
          git push --follow-tags
        env: { GITHUB_TOKEN: '${{ secrets.GITHUB_TOKEN }}' }

      - name: Detect affected
        id: targets
        run: |
          if [ -n "${{ github.event.inputs.app }}" ]; then
            APPS="${{ github.event.inputs.app }}"
          else
            APPS=$(bash scripts/affected.sh HEAD~1 | grep -E '@ds/(read-tracker|portfolio-tracker|task-list|bee|portal|landing)' || true)
          fi
          echo "apps=$APPS" >> "$GITHUB_OUTPUT"
          bash scripts/affected.sh HEAD~1 | grep -q '@ds/functions' && echo "functions=true" >> "$GITHUB_OUTPUT" || echo "functions=false" >> "$GITHUB_OUTPUT"
          git diff --name-only HEAD~1 | grep -q 'firestore.rules\|storage.rules' && echo "rules=true" >> "$GITHUB_OUTPUT" || echo "rules=false" >> "$GITHUB_OUTPUT"

      - name: Build deploy matrix
        id: matrix
        run: |
          MATRIX="["; FIRST=true
          for pkg in ${{ steps.targets.outputs.apps }}; do
            SLUG=$(echo "$pkg" | sed 's/@ds\///')
            DIR=$(bash scripts/pkg-dir.sh "$pkg")
            VER=$(node -e "console.log(require('./$DIR/package.json').version)")
            $FIRST || MATRIX="$MATRIX,"
            MATRIX="$MATRIX{\"package\":\"$pkg\",\"slug\":\"$SLUG\",\"version\":\"$VER\",\"dir\":\"$DIR\"}"
            FIRST=false
          done
          echo "matrix=${MATRIX}]" >> "$GITHUB_OUTPUT"

  deploy-app:
    needs: prepare
    if: needs.prepare.outputs.matrix != '[]'
    strategy:
      matrix:
        app: ${{ fromJson(needs.prepare.outputs.matrix) }}
      fail-fast: false                    # One app failing doesn't block others
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
        with: { ref: '${{ github.event.inputs.ref || github.sha }}' }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci
      - name: Build
        run: npm run build -w ${{ matrix.app.package }}
        env: { ... VITE_FIREBASE_* secrets ... }
      - name: Deploy to Firebase Hosting
        run: |
          echo "${{ secrets.FIREBASE_SERVICE_ACCOUNT }}" > /tmp/sa.json
          GOOGLE_APPLICATION_CREDENTIALS=/tmp/sa.json \
            npx firebase-tools@latest deploy \
            --only hosting:ds-${{ matrix.app.slug }} \
            --project ${{ vars.FIREBASE_PROJECT_ID }} \
            --non-interactive
        working-directory: ${{ matrix.app.dir }}
      - name: Tag
        run: |
          git tag "${{ matrix.app.slug }}-v${{ matrix.app.version }}" 2>/dev/null || true
          git tag "deploy-${{ matrix.app.slug }}-$(date +%Y%m%d)-$(echo ${{ github.sha }} | cut -c1-7)"
          git push origin --tags 2>/dev/null || true

  functions-deploy:
    needs: prepare
    if: needs.prepare.outputs.functions == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci && npm run build -w @ds/functions
      - run: |
          echo "${{ secrets.FIREBASE_SERVICE_ACCOUNT }}" > /tmp/sa.json
          GOOGLE_APPLICATION_CREDENTIALS=/tmp/sa.json \
            npx firebase-tools@latest deploy --only functions \
            --project ${{ vars.FIREBASE_PROJECT_ID }} --non-interactive

  rules-deploy:
    needs: prepare
    if: needs.prepare.outputs.rules == 'true'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - run: |
          echo "${{ secrets.FIREBASE_SERVICE_ACCOUNT }}" > /tmp/sa.json
          GOOGLE_APPLICATION_CREDENTIALS=/tmp/sa.json \
            npx firebase-tools@latest deploy --only firestore:rules,storage \
            --project ${{ vars.FIREBASE_PROJECT_ID }} --non-interactive
        working-directory: apps/portal

  notify:
    needs: [prepare, deploy-app]
    if: always() && needs.deploy-app.result == 'success'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: node .github/scripts/notify-discord-shipped.js
        env:
          DISCORD_RELAY_WEBHOOK_URL: ${{ secrets.DISCORD_RELAY_WEBHOOK_URL }}
          DISCORD_RELAY_WEBHOOK_SECRET: ${{ secrets.DISCORD_RELAY_WEBHOOK_SECRET }}
          AFFECTED_APPS: ${{ needs.prepare.outputs.matrix }}
          COMMIT_MESSAGE: ${{ github.event.head_commit.message }}
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

Each app rolls back independently:

1. **Firebase Console** — each site has its own deploy history. One-click rollback per app.
2. **Redeploy a tag** — `workflow_dispatch` with `ref` (tag) and `app` (@ds/read-tracker).
3. **Revert commit** — pipeline auto-deploys affected apps.

Rolling back Read Tracker does not affect any other app.

## Scaffolding New Apps

```bash
bash scripts/scaffold-app.sh my-new-app myApps
```

Creates standalone Vue app with auth, DS design system, `firebase.json` (targeting `ds-my-new-app`). Runs `firebase hosting:sites:create`. App is deployable immediately. No workflow changes needed — `affected.sh` picks it up automatically.

## Summary

| | Old (single SPA) | New (independent deploys) |
|---|---|---|
| **Build** | One Vite build for all apps | Each app builds independently |
| **Deploy** | One Firebase site, rebuild everything | Each app on its own Firebase site |
| **Blast radius** | Any change redeploys all apps | Only affected apps deploy |
| **Rollback** | Rollback entire portal | Rollback individual apps |
| **Add new app** | Add routes to monolith | Scaffold standalone app |
| **Dependencies** | All apps share one package.json | Each app has own dependencies |
| **Workflows** | 1 workflow rebuilds everything | 3 workflows, matrix deploys in parallel |

**3 workflow files. 2 helper scripts. 2 devDependencies (Changesets). Firebase multi-site (free tier).**

## Migration Steps

### Phase 1: Extract apps into independent builds
1. Create standalone `package.json`, `vite.config.ts`, `firebase.json` for each app
2. Move views/stores/composables from `apps/myapps/src/views/{App}/` into `apps/myApps/{app}/src/`
3. Extract shared code into `apps/shared/`
4. Verify each app builds independently

### Phase 2: Firebase multi-site
1. Create Firebase Hosting sites per app
2. Add DNS records for subdomains
3. Verify deploys per app

### Phase 3: Auth + shared
1. Implement `ensureAuth()` in `@ds/shared`
2. Test cross-subdomain sign-in

### Phase 4: CI/CD
1. Set up Changesets
2. Write `affected.sh` and `scaffold-app.sh`
3. Create 3 new workflows, delete old workflows
4. Create `production` GitHub Environment

### Phase 5: Portal conversion
1. Strip app code from portal — launcher/catalog only
2. Link to app subdomains

## Open Questions

1. **Subdomain vs. path URLs** — Subdomains (`read-tracker.darkstrawberry.com`) are zero-cost and clean for independent deploys. Paths (`apps.darkstrawberry.com/myApps/read-tracker`) require a reverse proxy. Duong to confirm.
