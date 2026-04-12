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
| **Portal** (apps platform) | `apps/portal/` (builds from platform, shared, all apps) | `apps.darkstrawberry.com` | default site | Firebase Hosting via GitHub Action |
| **Landing page** | `apps/landing/` | `darkstrawberry.com` | `darkstrawberry-landing` | Firebase Hosting via GitHub Action |
| **Cloud Functions** | `apps/functions/` | n/a | n/a | `firebase deploy --only functions` via GitHub Action |
| **Firestore Rules** | `apps/portal/firestore.rules` | n/a | n/a | `firebase deploy --only firestore:rules` via GitHub Action |
| **Storage Rules** | `apps/portal/storage.rules` | n/a | n/a | `firebase deploy --only storage` via GitHub Action |

## Evaluation: Build Orchestrators

### Context That Drives the Decision

Before comparing tools, the constraints that matter most:

1. **AI agents are the primary developers.** Sonnet agents build and ship apps. The deployment pipeline must be automatable — no interactive prompts, minimal ceremony, clear error messages.
2. **Single SPA constraint.** The portal is one Vite build. All apps are code-split chunks deployed together. You cannot deploy Read Tracker independently at the hosting level.
3. **Small scale, growing steadily.** <10 apps now, perhaps 20-30 eventually. One developer (Duong) + AI agents. Not a 50-person team with 200 packages.
4. **Firebase free tier.** No Vercel, no paid CI services.
5. **Per-app versioning and changelogs.** Each app must have its own release identity.

### Turborepo

**What it does well:** Dependency-aware task execution, remote caching, `--filter` for affected-only builds. Simple `turbo.json` config. Works with npm workspaces natively.

**Concerns for this project:**
- **Overhead vs. value at current scale.** With <10 packages and builds under 30 seconds, Turborepo's caching and parallelism save negligible time. The dependency graph is useful but simple enough to express in GitHub Actions path filters + a shared components list.
- **Remote caching requires Vercel account** (free tier exists but adds a dependency on Vercel infrastructure).
- **Agent complexity.** Agents now need to understand Turborepo's filter syntax, workspace resolution, and cache invalidation. When a build fails, the error may be in Turborepo's orchestration layer rather than in the app code — harder for agents to debug.
- **Lock-in to Turborepo's model.** If the project later needs something Turborepo doesn't support well (e.g., incremental deploys, custom affected detection), switching is painful.

**Verdict:** Good tool, wrong scale. Turborepo shines at 50+ packages where cache hits save minutes. At our scale, it adds complexity without proportional benefit.

### Nx

**What it does well:** Everything Turborepo does plus generators, migration tooling, and deeper IDE integration. Most sophisticated monorepo tool.

**Concerns for this project:**
- **Massive footprint.** Nx is a framework, not a tool. It wants to own your project structure, your linting config, your test setup. That's the opposite of what we need.
- **Steep learning curve** for agents and for Duong.
- **Even more overkill than Turborepo** at this scale.

**Verdict:** No. Designed for enterprise monorepos with hundreds of packages.

### npm Workspaces (bare)

**What it does well:** Native to npm. Zero additional dependencies. Each app gets its own `package.json` with its own version. `npm run -w @ds/read-tracker test` runs tests for one app.

**Concerns:**
- **No dependency-aware task execution.** If `@ds/shared` changes, you need to figure out which dependents to rebuild yourself.
- **No caching.**

**Verdict:** Too bare. We need dependency awareness.

### Recommended: npm Workspaces + Changesets + Simple Dependency Script

The right answer for this project is not a build orchestrator. It's **npm workspaces** (for per-app `package.json` and versioning) + **Changesets** (for per-app version management and changelogs) + a **small shell script** that computes affected packages from git diffs and the workspace dependency graph.

**Why this wins:**

1. **Minimal new dependencies.** `@changesets/cli` (for versioning) and a ~40 line `scripts/affected.sh` (for dependency-aware affected detection). No framework lock-in.
2. **Agents can operate it.** `npx changeset` is a simple command. The affected script outputs a plain list of package names. Errors are in familiar territory (npm, shell, git), not in an orchestrator's abstraction layer.
3. **Right-sized.** At <10 packages with sub-30-second builds, we don't need caching or parallelism. We need dependency awareness and per-app versioning. This delivers exactly that.
4. **Upgrade path.** If the project grows to 30+ packages and builds start taking minutes, drop in Turborepo. The workspace structure and Changesets config carry over unchanged — Turborepo reads `package.json` workspaces natively. The only change is replacing `scripts/affected.sh` with `turbo run --filter`.

## Architecture

### Workspace Structure

```
package.json                    # Root — workspaces config
.changeset/                     # Changesets config
  config.json
scripts/
  affected.sh                   # Computes affected packages from git diff
apps/
  portal/                       # @ds/portal — Vite root, app shell, router
    package.json                # version: "1.2.0", depends on all app packages
    firestore.rules
    storage.rules
  platform/                     # @ds/platform — nav, auth, app loader
    package.json                # version: "1.0.0", depends on @ds/shared
  shared/                       # @ds/shared — Firebase helpers, types, UI
    package.json                # version: "1.1.0"
  myApps/
    read-tracker/               # @ds/read-tracker
      package.json              # version: "2.1.0", depends on @ds/shared
      CHANGELOG.md              # Auto-generated by Changesets
    portfolio-tracker/          # @ds/portfolio-tracker
      package.json              # version: "1.1.2", depends on @ds/shared
      CHANGELOG.md
    task-list/                  # @ds/task-list
      package.json              # version: "0.9.0", depends on @ds/shared
      CHANGELOG.md
  yourApps/
    bee/                        # @ds/bee
      package.json              # version: "2.0.1", depends on @ds/shared
      CHANGELOG.md
  functions/                    # @ds/functions — Cloud Functions
    package.json                # version: "1.0.0"
    CHANGELOG.md
  landing/                      # @ds/landing — static HTML
    package.json                # version: "1.0.0"
```

### Root `package.json`

```json
{
  "private": true,
  "workspaces": [
    "apps/portal",
    "apps/platform",
    "apps/shared",
    "apps/myApps/*",
    "apps/yourApps/*",
    "apps/functions",
    "apps/landing"
  ],
  "scripts": {
    "build": "npm run build -w @ds/portal",
    "build:functions": "npm run build -w @ds/functions",
    "test": "npm run test -w @ds/portal",
    "lint": "npm run lint -w @ds/portal",
    "affected": "bash scripts/affected.sh"
  },
  "devDependencies": {
    "@changesets/cli": "^2.27.0",
    "@changesets/changelog-github": "^0.5.0"
  }
}
```

### `scripts/affected.sh` — Dependency-Aware Affected Detection

This is the key piece that replaces Turborepo's `--filter`. ~40 lines of POSIX bash.

```bash
#!/usr/bin/env bash
# Usage: scripts/affected.sh [base-ref]
# Outputs affected package names, one per line.
# Walks the workspace dependency graph: if @ds/shared changed,
# all packages depending on it are also affected.

set -euo pipefail
BASE="${1:-HEAD~1}"

# Get changed files
CHANGED_FILES=$(git diff --name-only "$BASE"...HEAD 2>/dev/null || git diff --name-only "$BASE" HEAD)

# Map changed files to workspace directories
CHANGED_DIRS=$(echo "$CHANGED_FILES" | grep '^apps/' | sed 's|/[^/]*$||' | sort -u)

# Read workspace package names from their package.json
declare -A DIR_TO_PKG
declare -A PKG_TO_DIR
for dir in apps/portal apps/platform apps/shared apps/myApps/* apps/yourApps/* apps/functions apps/landing; do
  [ -f "$dir/package.json" ] || continue
  pkg=$(node -e "console.log(require('./$dir/package.json').name)" 2>/dev/null) || continue
  DIR_TO_PKG["$dir"]="$pkg"
  PKG_TO_DIR["$pkg"]="$dir"
done

# Find directly changed packages
AFFECTED=()
for dir in $CHANGED_DIRS; do
  [ -n "${DIR_TO_PKG[$dir]:-}" ] && AFFECTED+=("${DIR_TO_PKG[$dir]}")
done

# Walk dependents: if @ds/shared is affected, find all packages that depend on it
QUEUE=("${AFFECTED[@]}")
SEEN=()
while [ ${#QUEUE[@]} -gt 0 ]; do
  PKG="${QUEUE[0]}"
  QUEUE=("${QUEUE[@]:1}")
  [[ " ${SEEN[*]} " == *" $PKG "* ]] && continue
  SEEN+=("$PKG")
  # Find packages that depend on $PKG
  for other_dir in "${!DIR_TO_PKG[@]}"; do
    other_pkg="${DIR_TO_PKG[$other_dir]}"
    if node -e "const d=require('./$other_dir/package.json').dependencies||{}; process.exit(d['$PKG']?0:1)" 2>/dev/null; then
      QUEUE+=("$other_pkg")
    fi
  done
done

printf '%s\n' "${SEEN[@]}" | sort -u
```

**What this gives us:**
- Change `apps/myApps/read-tracker/` -> affected: `@ds/read-tracker`, `@ds/portal`
- Change `apps/shared/` -> affected: `@ds/shared`, `@ds/read-tracker`, `@ds/portfolio-tracker`, `@ds/task-list`, `@ds/bee`, `@ds/platform`, `@ds/portal`
- Change `apps/functions/` -> affected: `@ds/functions` (independent)
- Change `apps/landing/` -> affected: `@ds/landing` (independent)

### Changesets — Per-App Versioning

[Changesets](https://github.com/changesets/changesets) handles per-package versioning and changelogs.

**Developer workflow (human or agent):**

1. Make changes to `@ds/read-tracker`
2. Run `npx changeset` — select package, bump type, write description:
   ```
   Which packages would you like to include? @ds/read-tracker
   What kind of change is this? minor
   Summary: Add reading goal streaks
   ```
3. This creates `.changeset/fuzzy-dogs.md`:
   ```markdown
   ---
   "@ds/read-tracker": minor
   ---
   Add reading goal streaks
   ```
4. Commit the changeset file with the PR
5. On merge, the release workflow runs `changeset version`:
   - Bumps `@ds/read-tracker` from 2.0.1 to 2.1.0 in its `package.json`
   - Appends to `apps/myApps/read-tracker/CHANGELOG.md`
   - If `@ds/shared` was also bumped, auto-patches all dependents
6. `changeset tag` creates git tags: `@ds/read-tracker@2.1.0`

**Agent automation:** Agents run `npx changeset add --empty` or write the changeset file directly (it's just a markdown file with YAML frontmatter). No interactive prompt needed.

**`.changeset/config.json`:**
```json
{
  "$schema": "https://github.com/changesets/changesets/blob/main/packages/config/schema.json",
  "changelog": ["@changesets/changelog-github", { "repo": "duongntd99/strawberry" }],
  "commit": false,
  "fixed": [],
  "linked": [],
  "access": "restricted",
  "baseBranch": "main",
  "updateInternalDependencies": "patch"
}
```

`updateInternalDependencies: "patch"` means: if `@ds/shared` gets any bump, all packages that depend on it get an automatic patch bump. This ensures dependent app versions reflect that their underlying dependencies changed.

### Version Display

Each app's version is read from `package.json` at build time:

```typescript
// In Vite config: define: { __APP_VERSION__: JSON.stringify(pkg.version) }
// In app footer: <span>v{{ __APP_VERSION__ }}</span>
```

The portal also embeds all app versions for debugging:
```typescript
window.__DS_APP_VERSIONS__ = {
  portal: "1.2.0",
  "read-tracker": "2.1.0",
  bee: "2.0.1",
  // ...
}
```

## Workflow Architecture

### Overview

```
PR opened/updated
  |
  +--> [ci.yml]
  |      scripts/affected.sh origin/main
  |      -> lint, test, build for affected packages
  |      -> E2E if @ds/portal affected
  |      -> Rules validation if rules files changed
  |
  +--> [preview.yml]
  |      If @ds/portal affected: build + Firebase preview channel
  |
  All checks pass -> merge to main
  |
  +--> [release.yml]
         scripts/affected.sh HEAD~1
         -> changeset version + tag (version bumps, changelogs, git tags)
         -> build affected packages
         -> deploy affected targets:
              portal: staging -> approval -> production
              functions: deploy
              landing: deploy
              rules: approval -> deploy
         -> Discord notification with affected apps + versions
```

**3 workflow files.** No per-app workflows needed — `scripts/affected.sh` determines what to build/test/deploy.

### 1. CI (`ci.yml`)

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

      - name: Compute affected packages
        id: affected
        run: |
          AFFECTED=$(bash scripts/affected.sh origin/main)
          echo "packages<<EOF" >> "$GITHUB_OUTPUT"
          echo "$AFFECTED" >> "$GITHUB_OUTPUT"
          echo "EOF" >> "$GITHUB_OUTPUT"
          echo "$AFFECTED" | grep -q '@ds/portal' && echo "portal=true" >> "$GITHUB_OUTPUT" || echo "portal=false" >> "$GITHUB_OUTPUT"

      - name: Lint + Test + Build affected
        run: |
          AFFECTED="${{ steps.affected.outputs.packages }}"
          for pkg in $AFFECTED; do
            echo "::group::$pkg"
            npm run lint -w "$pkg" --if-present
            npm run test -w "$pkg" --if-present
            npm run build -w "$pkg" --if-present
            echo "::endgroup::"
          done
        env:
          VITE_FIREBASE_API_KEY: ${{ secrets.VITE_FIREBASE_API_KEY }}
          VITE_FIREBASE_AUTH_DOMAIN: ${{ secrets.VITE_FIREBASE_AUTH_DOMAIN }}
          VITE_FIREBASE_PROJECT_ID: ${{ secrets.VITE_FIREBASE_PROJECT_ID }}
          VITE_FIREBASE_STORAGE_BUCKET: ${{ secrets.VITE_FIREBASE_STORAGE_BUCKET }}
          VITE_FIREBASE_MESSAGING_SENDER_ID: ${{ secrets.VITE_FIREBASE_MESSAGING_SENDER_ID }}
          VITE_FIREBASE_APP_ID: ${{ secrets.VITE_FIREBASE_APP_ID }}
          VITE_FIREBASE_MEASUREMENT_ID: ${{ secrets.VITE_FIREBASE_MEASUREMENT_ID }}

      - name: Validate Firestore rules
        if: contains(steps.affected.outputs.packages, 'firestore.rules') || contains(github.event.pull_request.title, 'rules')
        run: |
          echo "${{ secrets.FIREBASE_SERVICE_ACCOUNT }}" > /tmp/sa.json
          GOOGLE_APPLICATION_CREDENTIALS=/tmp/sa.json \
            npx firebase-tools@latest firestore:rules:validate apps/portal/firestore.rules \
            --project ${{ vars.FIREBASE_PROJECT_ID }}

      - name: E2E tests
        if: steps.affected.outputs.portal == 'true'
        run: |
          npm run build -w @ds/portal
          cd apps/portal && npx playwright test --project=chromium
        env: { ... VITE_FIREBASE_* secrets ... }

      - name: Upload Playwright report
        if: always() && steps.affected.outputs.portal == 'true'
        uses: actions/upload-artifact@v4
        with: { name: playwright-report, path: apps/portal/playwright-report/, retention-days: 7 }
```

### 2. Preview (`preview.yml`)

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

      - name: Check if portal affected
        id: check
        run: bash scripts/affected.sh origin/main | grep -q '@ds/portal' && echo "deploy=true" >> "$GITHUB_OUTPUT" || echo "deploy=false" >> "$GITHUB_OUTPUT"

      - name: Build portal
        if: steps.check.outputs.deploy == 'true'
        run: npm run build -w @ds/portal
        env: { ... VITE_FIREBASE_* secrets ... }

      - name: Deploy preview
        if: steps.check.outputs.deploy == 'true'
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          projectId: ${{ vars.FIREBASE_PROJECT_ID }}
          channelId: pr-${{ github.event.number }}
          entryPoint: apps/portal
          expires: 7d

      - name: Notify Discord
        if: steps.check.outputs.deploy == 'true'
        run: node .github/scripts/notify-discord-preview.js
        env:
          DISCORD_RELAY_WEBHOOK_URL: ${{ secrets.DISCORD_RELAY_WEBHOOK_URL }}
          DISCORD_RELAY_WEBHOOK_SECRET: ${{ secrets.DISCORD_RELAY_WEBHOOK_SECRET }}
          PREVIEW_URL: ${{ steps.firebase_deploy.outputs.details_url }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          PR_TITLE: ${{ github.event.pull_request.title }}
          PR_URL: ${{ github.event.pull_request.html_url }}
          REPO: ${{ github.repository }}
```

### 3. Release (`release.yml`)

```yaml
name: Release

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      ref:
        description: 'Git ref to deploy (tag or SHA for rollback)'
        required: false

concurrency:
  group: release
  cancel-in-progress: false

jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      portal: ${{ steps.targets.outputs.portal }}
      functions: ${{ steps.targets.outputs.functions }}
      landing: ${{ steps.targets.outputs.landing }}
      rules: ${{ steps.targets.outputs.rules }}
      affected_apps: ${{ steps.targets.outputs.affected_apps }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          ref: ${{ github.event.inputs.ref || github.sha }}
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci

      # Changesets: bump versions, update changelogs, create tags
      - name: Version packages
        run: |
          npx changeset version
          npx changeset tag
          git add -A
          git diff --cached --quiet || git commit -m "chore: version packages"
          git push --follow-tags
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      # Determine what to deploy
      - name: Detect affected targets
        id: targets
        run: |
          AFFECTED=$(bash scripts/affected.sh HEAD~1)
          echo "$AFFECTED"

          echo "portal=false" >> "$GITHUB_OUTPUT"
          echo "functions=false" >> "$GITHUB_OUTPUT"
          echo "landing=false" >> "$GITHUB_OUTPUT"
          echo "rules=false" >> "$GITHUB_OUTPUT"

          echo "$AFFECTED" | grep -q '@ds/portal'    && echo "portal=true"    >> "$GITHUB_OUTPUT"
          echo "$AFFECTED" | grep -q '@ds/functions'  && echo "functions=true" >> "$GITHUB_OUTPUT"
          echo "$AFFECTED" | grep -q '@ds/landing'    && echo "landing=true"   >> "$GITHUB_OUTPUT"
          git diff --name-only HEAD~1 | grep -q 'firestore.rules\|storage.rules' && echo "rules=true" >> "$GITHUB_OUTPUT"

          # Affected app names for Discord notification
          APP_LIST=$(echo "$AFFECTED" | sed 's/@ds\///' | tr '\n' ' ')
          echo "affected_apps=$APP_LIST" >> "$GITHUB_OUTPUT"

      # Build portal if affected
      - name: Build portal
        if: steps.targets.outputs.portal == 'true'
        run: npm run build -w @ds/portal
        env:
          VITE_FIREBASE_API_KEY: ${{ secrets.VITE_FIREBASE_API_KEY }}
          VITE_FIREBASE_AUTH_DOMAIN: ${{ secrets.VITE_FIREBASE_AUTH_DOMAIN }}
          VITE_FIREBASE_PROJECT_ID: ${{ secrets.VITE_FIREBASE_PROJECT_ID }}
          VITE_FIREBASE_STORAGE_BUCKET: ${{ secrets.VITE_FIREBASE_STORAGE_BUCKET }}
          VITE_FIREBASE_MESSAGING_SENDER_ID: ${{ secrets.VITE_FIREBASE_MESSAGING_SENDER_ID }}
          VITE_FIREBASE_APP_ID: ${{ secrets.VITE_FIREBASE_APP_ID }}
          VITE_FIREBASE_MEASUREMENT_ID: ${{ secrets.VITE_FIREBASE_MEASUREMENT_ID }}
      - uses: actions/upload-artifact@v4
        if: steps.targets.outputs.portal == 'true'
        with: { name: portal-dist, path: apps/portal/dist/ }

  # --- Portal: staging -> production ---
  portal-staging:
    needs: prepare
    if: needs.prepare.outputs.portal == 'true'
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

  portal-production:
    needs: [prepare, portal-staging]
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
        env:
          DISCORD_RELAY_WEBHOOK_URL: ${{ secrets.DISCORD_RELAY_WEBHOOK_URL }}
          DISCORD_RELAY_WEBHOOK_SECRET: ${{ secrets.DISCORD_RELAY_WEBHOOK_SECRET }}
          AFFECTED_APPS: ${{ needs.prepare.outputs.affected_apps }}
          COMMIT_MESSAGE: ${{ github.event.head_commit.message }}
          REPO: ${{ github.repository }}
        run: node .github/scripts/notify-discord-shipped.js

  # --- Functions deploy ---
  functions-deploy:
    needs: prepare
    if: needs.prepare.outputs.functions == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm run build -w @ds/functions
      - name: Deploy functions
        run: |
          echo "${{ secrets.FIREBASE_SERVICE_ACCOUNT }}" > /tmp/sa.json
          GOOGLE_APPLICATION_CREDENTIALS=/tmp/sa.json \
            npx firebase-tools@latest deploy --only functions \
            --project ${{ vars.FIREBASE_PROJECT_ID }} --non-interactive

  # --- Landing deploy ---
  landing-deploy:
    needs: prepare
    if: needs.prepare.outputs.landing == 'true'
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
    needs: prepare
    if: needs.prepare.outputs.rules == 'true'
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

## Rollback Plan

### Portal Rollback

Firebase Hosting keeps the last several deploys. Three options, fastest to slowest:

1. **Firebase Console** — one-click rollback to any previous deploy. < 1 minute.
2. **Redeploy a tag** — trigger `release.yml` via `workflow_dispatch` with a git ref (e.g. `deploy-portal-20260411-abc1234` or `@ds/read-tracker@2.0.0`).
3. **Revert commit** — `git revert` the bad commit, push to main, pipeline runs automatically.

### Functions Rollback

1. **Revert commit** — push a revert, let the pipeline redeploy.
2. **Manual deploy from tag** — check out the tag locally, run `firebase deploy --only functions`.

### Rules Rollback

Same as functions. Rules deploys require the `production` environment approval gate, so bad rules should be caught before they ship.

## GitHub Environments

| Environment | Approval Required | Used By |
|-------------|-------------------|---------|
| `staging` | No | Portal staging deploy |
| `production` | Yes (Duong) | Portal prod deploy, Rules deploy |

## Workflow Summary

| Workflow | Trigger | What It Does |
|----------|---------|-------------|
| `ci.yml` | PR | `affected.sh` -> lint/test/build affected + E2E if portal affected + rules validation |
| `preview.yml` | PR | Build + Firebase preview channel deploy if portal affected |
| `release.yml` | push to main / manual dispatch | Changesets version/tag -> build affected -> deploy affected targets (portal staging->prod, functions, landing, rules) |

**3 workflow files. 1 shell script. 2 npm devDependencies.**

### Adding a New App

1. Create `apps/myApps/new-app/package.json` with `"name": "@ds/new-app"`, `"version": "0.1.0"`
2. Add dependency in `apps/portal/package.json`: `"@ds/new-app": "workspace:*"`
3. `affected.sh` automatically picks it up via the workspace dependency graph
4. No new workflow files. No config changes.

### Upgrade Path to Turborepo

If the project grows to 30+ packages and builds take over a minute:

1. `npm install -D turbo`
2. Add `turbo.json` with pipeline config
3. Replace `affected.sh` calls in workflows with `turbo run --filter=...[ref]`
4. Everything else (workspaces, Changesets, workflows, firebase.json) stays identical

This is a 30-minute migration because the workspace structure is designed for it.

## New Dependencies

| Package | Purpose | Dev/Prod |
|---------|---------|----------|
| `@changesets/cli` | Per-package versioning + changelogs | devDependency (root) |
| `@changesets/changelog-github` | GitHub-linked changelog entries | devDependency (root) |

No Turborepo. No Nx. No framework lock-in.

## Migration Steps

### Phase 1: Workspaces
1. Create root `package.json` with `workspaces` config
2. Add `package.json` to each app directory (portal, platform, shared, each myApp, each yourApp, functions, landing) with `@ds/{name}` naming and initial versions
3. Migrate imports to use workspace resolution
4. Verify `npm run build -w @ds/portal` works locally

### Phase 2: Changesets
1. `npx changeset init`
2. Configure `.changeset/config.json`
3. Verify `npx changeset` works (create a test changeset, run `changeset version`, check version bumps)

### Phase 3: Affected script
1. Write `scripts/affected.sh`
2. Verify it correctly identifies affected packages for: single-app change, shared change, functions-only change

### Phase 4: CI migration
1. Create `staging` and `production` GitHub Environments
2. Add Duong as required reviewer for `production`
3. Create `ci.yml`, `preview.yml`, `release.yml`
4. Delete old workflows: `myapps-prod-deploy.yml`, `myapps-pr-preview.yml`, `myapps-test.yml`, `landing-prod-deploy.yml`
5. Test with a PR touching one app, then a PR touching shared

## Open Questions

None.
