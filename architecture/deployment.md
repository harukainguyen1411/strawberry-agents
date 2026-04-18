# Deployment Architecture

## What deploys where

| Product | URL | Host | Build entry |
|---------|-----|------|-------------|
| Dark Strawberry portal | `apps.darkstrawberry.com` | Firebase Hosting (`myapps-b31ea`) | `apps/myapps/` |
| Dark Strawberry landing | `darkstrawberry.com` | Firebase Hosting (`myapps-b31ea`) | `apps/landing/` |

Both products share one Firebase project (`myapps-b31ea`). The portal is the primary SPA; the landing page is a static site.

## Portal build — source paths

The portal is a single Vite build from `apps/myapps/`. It imports code from multiple directories:

| Directory | Role |
|-----------|------|
| `apps/myapps/src/` | Active SPA entry — router, stores, views, Firebase config |
| `apps/platform/src/` | Platform shell — app loader, registry, access control, new views |
| `apps/shared/` | Cross-app utilities — `appFirestore.ts` helpers, shared types |
| `apps/myApps/` | Individual myApps (read-tracker, portfolio-tracker, task-list) |
| `apps/yourApps/` | Individual yourApps (bee, future personal apps) |

A change to any of these directories requires a portal rebuild and redeploy.

## CI workflows

### `myapps-prod-deploy.yml` — production deploy
- **Trigger:** push to `main` touching any of:
  - `apps/myapps/**`
  - `apps/platform/**`
  - `apps/shared/**`
  - `apps/myApps/**`
  - `apps/yourApps/**`
- **Steps:** checkout → install → build (with `VITE_FIREBASE_*` secrets) → deploy to Firebase Hosting (live channel) → notify Discord
- **Firebase project:** `myapps-b31ea`
- **Entry point:** `apps/myapps/`

### `myapps-pr-preview.yml` — PR preview deploy
- **Trigger:** PR to `main` (no paths filter — always runs for required status check)
- **Change detection:** skips build/deploy if no platform paths changed
- **Steps:** checkout → change detect → install → build → deploy to preview channel `pr-{number}` (7-day TTL) → notify Discord
- **Required status check on `main`:** yes (`Firebase Hosting PR Preview / preview`)

### `myapps-test.yml` — test gate
- **Trigger:** PR to `main` (no paths filter)
- **Change detection:** skips if no platform paths changed
- **Jobs:**
  - `unit` — Vitest (`npm run test:run`)
  - `e2e` — Playwright Chromium (`npm run test:e2e:ci`), uploads report artifact
- **Required status checks on `main`:** both jobs required (`Unit tests (Vitest)`, `E2E tests (Playwright / Chromium)`)

### `landing-prod-deploy.yml` — landing page deploy
- **Trigger:** push to `main` touching `apps/landing/**`
- **Deploys:** `apps/landing/` static site to Firebase Hosting

### `validate-scope.yml` — commit prefix guard
- **Trigger:** PR to `main`
- **Checks:** all commits use `chore:` or `ops:` prefix
- **Required status check on `main`:** yes

## Release flow

```
feature branch  →  PR  →  4 required checks pass  →  merge to main  →  auto-deploy to prod
                           ├─ validate-scope
                           ├─ unit tests (Vitest)
                           ├─ e2e tests (Playwright)
                           └─ PR preview (Firebase Hosting)
```

1. Developer pushes to a feature branch (always via `git worktree`, never raw checkout)
2. PR opened against `main` — all 4 required checks must pass
3. PR preview channel deployed automatically for visual review
4. On merge: `myapps-prod-deploy.yml` triggers if any platform path changed → build → live deploy → Discord notification

## Secrets required (on `harukainguyen1411/strawberry-app`)

| Secret | Used by |
|--------|---------|
| `VITE_FIREBASE_API_KEY` | prod deploy, PR preview |
| `VITE_FIREBASE_AUTH_DOMAIN` | prod deploy, PR preview |
| `VITE_FIREBASE_PROJECT_ID` | prod deploy, PR preview |
| `VITE_FIREBASE_STORAGE_BUCKET` | prod deploy, PR preview |
| `VITE_FIREBASE_MESSAGING_SENDER_ID` | prod deploy, PR preview |
| `VITE_FIREBASE_APP_ID` | prod deploy, PR preview |
| `VITE_FIREBASE_MEASUREMENT_ID` | prod deploy, PR preview |
| `FIREBASE_SERVICE_ACCOUNT` | prod deploy, PR preview (Firebase action) |
| `DISCORD_RELAY_WEBHOOK_URL` | prod deploy, PR preview (notifications) |
| `DISCORD_RELAY_WEBHOOK_SECRET` | prod deploy, PR preview (notifications) |

## Variables required (on `harukainguyen1411/strawberry-app`)

| Variable | Value |
|----------|-------|
| `FIREBASE_PROJECT_ID` | `myapps-b31ea` |
