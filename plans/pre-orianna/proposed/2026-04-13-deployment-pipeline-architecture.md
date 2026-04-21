---
status: proposed
owner: swain
created: 2026-04-13
tags: [architecture, deploy, dark-strawberry, pipeline, ci-cd]
---

# Dark Strawberry Deployment Pipeline Architecture

> **For agentic workers:** This is an architecture plan, not a step-by-step implementation guide. Each component section contains enough detail for an implementer to work without further questions. Implement in phase order (P0 first).

## Incident Recap

On 2026-04-13, `apps.darkstrawberry.com` served a blank page to all users for approximately one hour. The root cause was a Turborepo cache poisoning: a build artifact produced without `VITE_FIREBASE_*` environment variables was cached, then silently reused across subsequent deploys. The site failed at runtime with `Missing Firebase configuration`. No automated test caught this. Recovery required manual cache-busting, rebuild, and redeploy. The incident-patch plan (`plans/proposed/2026-04-13-deploy-pipeline-hardening.md`) addresses the immediate bug. This plan designs the proper deployment pipeline to make this class of failure structurally impossible.

## Current State Audit

The existing infrastructure is more capable than it may appear at first glance. A candid inventory:

**What exists:**
- CI workflow (`ci.yml`): lint, build, unit tests, Playwright E2E on PRs. Secrets via GitHub Actions. Works.
- PR preview workflow (`preview.yml` + `myapps-pr-preview.yml`): Firebase preview channels (`pr-{number}`), 7-day expiry, Discord notification with preview URL. Two competing workflows doing similar things (duplication).
- Release workflow (`release.yml`): Triggered on main push. `environment: production` (GitHub environment protection gate). Changesets version + tag. Composite deploy. Deploy tag (`deploy-portal-YYYYMMDD-sha7`). Discord notification. Supports rollback via `workflow_dispatch` with a git ref input.
- Landing deploy (`landing-prod-deploy.yml`): Separate path-triggered workflow for `apps/landing`.
- Legacy myapps-specific deploy (`myapps-prod-deploy.yml`): Also triggers on main push for apps paths. **Conflicts with `release.yml`** -- both fire on the same event, potentially double-deploying.
- Composite deploy script (`scripts/composite-deploy.sh`): Assembles all app `dist/` folders into a single `deploy/` directory. No validation.
- Turbo cache: No env var hashing in `turbo.json` -- the gap that caused the incident.
- Secrets: GitHub Actions secrets configured for all `VITE_FIREBASE_*` vars + `FIREBASE_SERVICE_ACCOUNT`. Local dev still depends on `.env.local` on Duong's laptop.

**What is missing:**
- No build-time env validation (builds succeed silently with missing vars).
- No post-deploy smoke test (broken deploys are user-discovered).
- No staging environment (main merges go straight to production via the release workflow).
- No `version.json` or build SHA injection (no way to verify what commit is live).
- Turbo cache keys do not include `.env*` or env var values.
- No post-deploy health check or observability pipeline.
- Duplicate/conflicting workflows (`myapps-prod-deploy.yml` vs `release.yml`).
- No centralized secrets management for local dev beyond Duong's `.env.local`.

## Target-State Architecture

```
PR opened/updated
  |
  v
ci.yml: lint + build + unit tests + E2E
  |                              \
  v                               v
preview.yml: composite deploy   PR comment with
  to preview channel              preview URL
  (pr-{number}, 7d expiry)
  |
  v
PR merged to main
  |
  v
release.yml: build (--force, no turbo cache)
  |
  v
Env validation (Vite plugin, fail-fast)
  |
  v
Inject VITE_BUILD_SHA + timestamp
  |
  v
Composite deploy -> staging channel
  |
  v
Smoke test against staging URL (Playwright)
  |
  +--> FAIL: Discord alert, block promotion, exit
  |
  v (PASS)
Manual approval gate (GitHub environment: production)
  |
  v
Promote: deploy to live channel
  |
  v
Post-deploy smoke test against production URLs
  |
  +--> FAIL: auto-rollback + Discord alert
  |
  v (PASS)
Tag deploy (deploy-portal-YYYYMMDD-sha7)
  |
  v
Discord notification: shipped
  |
  v
version.json accessible at /version.json
```

**Rollback path:**
```
workflow_dispatch with ref=<deploy-tag>
  -> checkout that ref
  -> build + composite deploy
  -> deploy to live (skip staging)
  -> smoke test
  -> tag as rollback-YYYYMMDD-sha7
```

---

## Component Design

### C1: Reproducible Builds in CI (existing, needs hardening)

**Rationale:** Builds must never depend on Duong's laptop state. CI already builds in GitHub Actions, but the release workflow uses Turbo cache (which caused the incident). Production builds must be cache-free.

**Implementation:**

1. In `release.yml`, change the build step from `npx turbo run build` to `npx turbo run build --force`. This disables Turbo's local cache for production builds. The 2-3 minute build cost is negligible against the risk.

2. Keep Turbo caching enabled in `ci.yml` and `preview.yml` -- speed matters for PR feedback loops, and a bad cache in preview is low-risk (caught by review).

3. Pin Node version in all workflows to `20` (already done). Add `npm ci` (already done) to guarantee lockfile-reproducible installs.

**Files to modify:**
- `.github/workflows/release.yml`: line 49, add `--force` flag

**Acceptance test:** Run release workflow. Turbo output should show `0 cached, N total` for all apps.

---

### C2: PR Preview Channels (existing, needs deduplication)

**Rationale:** Two workflows (`preview.yml` and `myapps-pr-preview.yml`) both deploy previews on PR. One uses the monorepo composite deploy; the other builds only `apps/myapps`. This is confusing and wastes Actions minutes.

**Implementation:**

1. Delete `myapps-pr-preview.yml`. Keep `preview.yml` as the single preview workflow since it does the full composite build (all apps visible at their correct paths).

2. Ensure `preview.yml` passes env vars to the build step (already does).

3. The `FirebaseExtended/action-hosting-deploy` action already posts a PR comment with the preview URL. Discord notification also exists. No changes needed there.

**Files to modify:**
- Delete `.github/workflows/myapps-pr-preview.yml`
- Verify `preview.yml` has no regressions

**Acceptance test:** Open a PR that changes `apps/myapps`. Confirm exactly one preview deploy runs, one PR comment appears with the preview URL.

---

### C3: Staging Environment

**Rationale:** Today, merging to main deploys directly to production. A staging channel provides a buffer where the full composite site can be validated before going live.

**Implementation:**

1. Use Firebase Hosting's preview channels for staging. Channel name: `staging`. Unlike PR channels, this one does not expire.

2. Modify `release.yml` to deploy first to `staging` channel instead of `live`:

   ```yaml
   - name: Deploy to staging channel
     id: staging_deploy
     uses: FirebaseExtended/action-hosting-deploy@v0
     with:
       repoToken: ${{ secrets.GITHUB_TOKEN }}
       firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
       channelId: staging
       projectId: ${{ vars.FIREBASE_PROJECT_ID }}
   ```

3. The staging URL will be `https://myapps-b31ea--staging-{hash}.web.app`. This is stable enough for smoke tests.

4. Production promotion happens as a separate job gated by the `production` environment (which already has protection rules configured in GitHub).

**Files to modify:**
- `.github/workflows/release.yml`: Split `deploy-portal` job into `deploy-staging` + `deploy-production`

**Acceptance test:** Merge to main. Confirm staging channel receives the deploy. Confirm production does not update until manual approval is given in the GitHub Actions UI.

---

### C4: Gated Promotion to Production

**Rationale:** No code should reach production without passing smoke tests on staging AND receiving explicit human approval (or passing an automated gate).

**Implementation:**

The `release.yml` workflow already uses `environment: production`. The change is structural: split into two jobs.

```yaml
jobs:
  build-and-stage:
    runs-on: ubuntu-latest
    outputs:
      staging_url: ${{ steps.staging_deploy.outputs.details_url }}
    steps:
      # checkout, setup-node, npm ci, build --force, composite deploy
      - name: Deploy to staging channel
        id: staging_deploy
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          channelId: staging
          # ...

  smoke-test-staging:
    needs: build-and-stage
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npx playwright install chromium --with-deps
      - name: Smoke test staging
        run: node scripts/smoke-test.mjs "${{ needs.build-and-stage.outputs.staging_url }}"

  deploy-production:
    needs: [build-and-stage, smoke-test-staging]
    runs-on: ubuntu-latest
    environment: production    # <-- manual approval gate
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.sha }}
      # Re-use the same build artifact? No -- rebuild is cheap and guarantees bit-for-bit correctness.
      # Alternatively, upload/download artifact between jobs.
      - name: Download staged deploy artifact
        uses: actions/download-artifact@v4
        with:
          name: deploy-dir
      - name: Deploy to live
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          channelId: live
          # ...
```

**Optimization:** To avoid rebuilding in `deploy-production`, the `build-and-stage` job should upload the `deploy/` directory as a GitHub Actions artifact. The production job downloads it and deploys.

```yaml
# In build-and-stage:
- name: Upload deploy artifact
  uses: actions/upload-artifact@v4
  with:
    name: deploy-dir
    path: deploy/
    retention-days: 1
```

**Files to modify:**
- `.github/workflows/release.yml`: Major restructure into 3 jobs
- Delete `.github/workflows/myapps-prod-deploy.yml` (conflicts with release.yml)

**Acceptance test:** Merge to main. Staging deploys automatically. Production job waits for approval in GitHub UI. After approval, production deploys the same artifact.

---

### C5: Build-Time Env Validation

**Rationale:** The 2026-04-13 incident bundle was built without Firebase env vars and deployed silently. Fail the build loudly if required vars are missing.

**Implementation:**

1. Create `apps/shared/vite-plugins/env-validation.ts`:

   ```typescript
   import type { Plugin } from 'vite';

   const REQUIRED_FIREBASE_VARS = [
     'VITE_FIREBASE_API_KEY',
     'VITE_FIREBASE_AUTH_DOMAIN',
     'VITE_FIREBASE_PROJECT_ID',
     'VITE_FIREBASE_STORAGE_BUCKET',
     'VITE_FIREBASE_MESSAGING_SENDER_ID',
     'VITE_FIREBASE_APP_ID',
   ] as const;

   export function envValidation(extra: string[] = []): Plugin {
     return {
       name: 'env-validation',
       configResolved(config) {
         if (config.command !== 'build') return; // skip in dev
         const missing = [...REQUIRED_FIREBASE_VARS, ...extra]
           .filter(v => !process.env[v]);
         if (missing.length > 0) {
           throw new Error(
             `Build aborted: missing required env vars:\n` +
             missing.map(v => `  - ${v}`).join('\n') +
             `\nEnsure .env.local is present or vars are set in CI.`
           );
         }
       },
     };
   }
   ```

2. Each app's `vite.config.ts` adds the plugin:

   ```typescript
   import { envValidation } from '@ds/shared/vite-plugins/env-validation';
   // ...
   plugins: [envValidation(), /* ... */]
   ```

3. Apps that do NOT use Firebase (e.g., `apps/landing` if it's static) skip the plugin or use `envValidation([])` with an empty required list.

**Files to create:**
- `apps/shared/vite-plugins/env-validation.ts`

**Files to modify:**
- Every `apps/*/vite.config.ts` that uses Firebase

**Acceptance test:** Remove `VITE_FIREBASE_API_KEY` from env, run `npm run build`. Build fails with clear error. Restore var, build succeeds.

---

### C6: Pre-Deploy Smoke Test

**Rationale:** Even with env validation, smoke tests are the last line of defense. A Playwright test against the staged URL catches runtime failures that build-time checks cannot.

**Implementation:**

1. Create `scripts/smoke-test.mjs`:

   ```javascript
   #!/usr/bin/env node
   import { chromium } from 'playwright';

   const urls = process.argv.slice(2);
   if (urls.length === 0) {
     // Default to production URLs
     urls.push('https://darkstrawberry.com', 'https://apps.darkstrawberry.com');
   }

   let exitCode = 0;

   for (const url of urls) {
     const browser = await chromium.launch();
     const page = await browser.newPage();
     const errors = [];
     page.on('console', msg => {
       if (msg.type() === 'error') errors.push(msg.text());
     });

     try {
       await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });

       const title = await page.title();
       if (!title || title === 'about:blank') {
         throw new Error(`Empty or default page title: "${title}"`);
       }

       // Check that the app root has rendered children
       const appRoot = await page.$('#app, #root, [data-app]');
       if (appRoot) {
         const childCount = await appRoot.evaluate(el => el.children.length);
         if (childCount === 0) {
           throw new Error('App root element has zero children — blank page');
         }
       }

       if (errors.length > 0) {
         throw new Error(`Console errors:\n${errors.join('\n')}`);
       }

       console.log(`PASS: ${url}`);
     } catch (err) {
       console.error(`FAIL: ${url} — ${err.message}`);
       exitCode = 1;
     } finally {
       await browser.close();
     }
   }

   process.exit(exitCode);
   ```

2. In `release.yml`, the `smoke-test-staging` job runs this against the staging URL output.

3. In the `deploy-production` job, add a post-deploy smoke step targeting the production URLs.

**Files to create:**
- `scripts/smoke-test.mjs`

**Acceptance test:** Run `node scripts/smoke-test.mjs https://apps.darkstrawberry.com`. Should print `PASS`. Run against a broken URL. Should print `FAIL` and exit non-zero.

---

### C7: Version Visibility

**Rationale:** "What commit is live?" should be answerable with `curl`. Currently there is no way to know without checking Firebase release history.

**Implementation:**

1. Create a Vite plugin `apps/shared/vite-plugins/build-info.ts`:

   ```typescript
   import type { Plugin } from 'vite';

   export function buildInfo(): Plugin {
     return {
       name: 'build-info',
       config() {
         return {
           define: {
             '__BUILD_SHA__': JSON.stringify(process.env.GITHUB_SHA || process.env.VITE_BUILD_SHA || 'local'),
             '__BUILD_TIME__': JSON.stringify(new Date().toISOString()),
           },
         };
       },
     };
   }
   ```

2. In `scripts/composite-deploy.sh`, after assembling the deploy directory, write a `version.json`:

   ```bash
   cat > "$ROOT_DIR/$DEPLOY_DIR/version.json" <<EOF
   {
     "sha": "${GITHUB_SHA:-local}",
     "ref": "${GITHUB_REF:-local}",
     "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
     "buildId": "${GITHUB_RUN_ID:-local}"
   }
   EOF
   ```

3. Optionally render the SHA in a footer component (low priority -- `version.json` is the primary mechanism).

4. In smoke tests, after verifying the page loads, also fetch `/version.json` and confirm the SHA matches `GITHUB_SHA`.

**Files to create:**
- `apps/shared/vite-plugins/build-info.ts`

**Files to modify:**
- `scripts/composite-deploy.sh`: Add version.json generation
- Each app's `vite.config.ts`: Add `buildInfo()` plugin

**Acceptance test:** After deploy, `curl https://apps.darkstrawberry.com/version.json` returns JSON with a valid SHA and timestamp.

---

### C8: Rollback

**Rationale:** Recovery from a bad deploy must be a single action, not a multi-step manual process.

**Implementation:**

The `release.yml` already supports rollback via `workflow_dispatch` with a `ref` input. This needs documentation and a post-deploy-smoke failure path.

1. Create `architecture/deploy-runbook.md`:

   ```markdown
   # Deploy Runbook

   ## Standard Deploy
   Merge PR to main. Release workflow auto-deploys to staging.
   Approve in GitHub Actions UI to promote to production.

   ## Emergency Rollback (Option A: Firebase)
   Instant, no rebuild:
     firebase hosting:rollback --project myapps-b31ea

   ## Emergency Rollback (Option B: Git ref redeploy)
   Find the last good deploy tag:
     git tag -l 'deploy-portal-*' --sort=-creatordate | head -5

   Trigger rollback:
     gh workflow run release.yml -f ref=deploy-portal-20260413-abc1234

   ## Auto-Rollback on Smoke Failure
   If post-production smoke fails, the workflow automatically:
   1. Runs `firebase hosting:rollback`
   2. Sends a Discord alert
   3. Exits non-zero
   ```

2. In `release.yml` `deploy-production` job, after the post-deploy smoke test fails:

   ```yaml
   - name: Auto-rollback on smoke failure
     if: failure() && steps.prod_smoke.outcome == 'failure'
     run: |
       echo '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}' > /tmp/sa.json
       GOOGLE_APPLICATION_CREDENTIALS=/tmp/sa.json \
         npx firebase-tools@latest hosting:rollback \
         --project ${{ vars.FIREBASE_PROJECT_ID }} --non-interactive
     env:
       GOOGLE_APPLICATION_CREDENTIALS: /tmp/sa.json
   ```

**Files to create:**
- `architecture/deploy-runbook.md`

**Files to modify:**
- `.github/workflows/release.yml`

**Acceptance test:** Trigger `workflow_dispatch` with a known-good tag. Confirm the site reverts to that version's content.

---

### C9: Observability

**Rationale:** Post-deploy, we need to know if error rates spike. Currently, broken deploys are user-discovered.

**Implementation:**

1. **Sentry (free tier, 5k errors/month):** Add `@sentry/browser` to `apps/myapps` and any other app that should be monitored. Initialize with the build SHA as the release identifier. This gives error grouping, source maps, and release tracking.

   ```typescript
   import * as Sentry from '@sentry/browser';
   Sentry.init({
     dsn: import.meta.env.VITE_SENTRY_DSN,
     release: __BUILD_SHA__,
     environment: import.meta.env.MODE,
   });
   ```

2. **Source map upload:** In CI, after build, upload source maps to Sentry:

   ```yaml
   - name: Upload source maps to Sentry
     run: npx @sentry/cli sourcemaps inject --release ${{ github.sha }} ./deploy
     env:
       SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
       SENTRY_ORG: darkstrawberry
       SENTRY_PROJECT: apps
   ```

3. **Discord alert on error spike:** Use Sentry's built-in alerting (free tier supports it). Configure an alert rule: if error count exceeds 10 in 15 minutes, fire a webhook to the Discord relay.

4. **Alternative (lower effort):** Skip Sentry initially. Use Firebase Performance Monitoring (already included in the Firebase SDK) + Firebase Crashlytics for web. Less powerful but zero additional setup cost.

**Files to modify:**
- `apps/myapps/src/main.ts` (or equivalent entry point)
- `.github/workflows/release.yml`: Source map upload step

**New secrets needed:**
- `VITE_SENTRY_DSN` (GitHub Actions secret + `.env.local`)
- `SENTRY_AUTH_TOKEN` (GitHub Actions secret only)

**Acceptance test:** Deploy with Sentry. Trigger a JS error. Confirm it appears in Sentry dashboard within 60 seconds with the correct release SHA.

---

### C10: Secrets Management

**Rationale:** `.env.local` on Duong's laptop is the only source of truth for local dev secrets. If the laptop dies, local dev is blocked until secrets are reconstructed.

**Implementation:**

1. **CI secrets:** Already in GitHub Actions secrets. No change needed.

2. **Local dev secrets:** The repo already has `tools/decrypt.sh` and age-encrypted secrets in `secrets/`. Extend this:

   - Create `secrets/encrypted/env.local.age` containing the encrypted `.env.local` contents.
   - Add a script `scripts/setup-env.sh`:

     ```bash
     #!/usr/bin/env bash
     # Decrypts secrets and writes .env.local files for local dev.
     set -euo pipefail
     ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
     source "$ROOT/tools/decrypt.sh" secrets/encrypted/env.local.age > "$ROOT/apps/myapps/.env.local"
     echo "Wrote apps/myapps/.env.local from encrypted source."
     ```

   - Document in the deploy runbook: "For local dev, run `bash scripts/setup-env.sh` after cloning."

3. **Secret rotation:** Document that when a Firebase key rotates, update both GitHub Actions secrets AND `secrets/encrypted/env.local.age`.

**Files to create:**
- `secrets/encrypted/env.local.age` (Duong encrypts manually)
- `scripts/setup-env.sh`

**Acceptance test:** Delete `apps/myapps/.env.local`. Run `bash scripts/setup-env.sh`. File is recreated with correct contents. `npm run build` succeeds.

---

### C11: Turbo Cache Correctness

**Rationale:** The direct cause of the 2026-04-13 incident. `turbo.json` does not hash env vars or `.env*` files into cache keys.

**Implementation:**

Update `turbo.json`:

```json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDotEnv": [".env", ".env.local"],
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"],
      "dotEnv": [".env", ".env.local", ".env.production", ".env.production.local"],
      "env": [
        "VITE_FIREBASE_API_KEY",
        "VITE_FIREBASE_AUTH_DOMAIN",
        "VITE_FIREBASE_PROJECT_ID",
        "VITE_FIREBASE_STORAGE_BUCKET",
        "VITE_FIREBASE_MESSAGING_SENDER_ID",
        "VITE_FIREBASE_APP_ID",
        "VITE_FIREBASE_MEASUREMENT_ID",
        "VITE_SENTRY_DSN",
        "VITE_BUILD_SHA"
      ]
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
    },
    "test:e2e:ci": {
      "dependsOn": ["build"],
      "cache": false
    }
  }
}
```

**Files to modify:**
- `turbo.json`

**Acceptance test:**
- `npm run build` twice, identical env. Second run: fully cached.
- Change `VITE_FIREBASE_API_KEY` value. `npm run build`. Turbo reports cache miss.

---

### C12: Changesets Integration

**Rationale:** `@changesets/cli` is already a devDependency. The release workflow already runs `changeset version` and `changeset tag`. But the PR workflow does not enforce changeset presence.

**Implementation:**

1. Add a changeset bot check to CI. The `changesets/action` GitHub Action can do this:

   ```yaml
   # In ci.yml, add a job:
   changeset-check:
     runs-on: ubuntu-latest
     steps:
       - uses: actions/checkout@v4
         with: { fetch-depth: 0 }
       - uses: actions/setup-node@v4
         with: { node-version: 20, cache: npm }
       - run: npm ci
       - name: Check for changeset
         run: npx changeset status --since=origin/main
   ```

2. This fails if a PR touches app code but has no changeset file. Contributors run `npx changeset` to add one.

3. The existing release workflow's changeset version step is already correct. Confirm it pushes version bumps and tags back to main.

**Files to modify:**
- `.github/workflows/ci.yml`: Add changeset check job

**Acceptance test:** Open a PR that changes `apps/myapps/src/` without a changeset file. CI fails with a changeset status error. Add a changeset, push, CI passes.

---

## Workflow Cleanup: Eliminate Conflicts

Before implementing any of the above, clean up the existing workflow duplication:

1. **Delete `myapps-prod-deploy.yml`** -- it conflicts with `release.yml`. Both trigger on `push` to `main`. The release workflow is the correct one (it has environment protection, deploy tags, changesets).

2. **Delete `myapps-pr-preview.yml`** -- it conflicts with `preview.yml`. The composite `preview.yml` is correct (full site preview vs. single-app preview).

3. **Rename `preview.yml`** to something clearer if desired (e.g., `pr-preview.yml`), but this is cosmetic.

---

## Phasing

### P0: Minimum Viable Pipeline (items C1, C4, C5, C7, C8, C11 + cleanup)

**Goal:** Every production deploy is reproducible, validated, gated, traceable, and rollbackable.

| Task | Effort | Description |
|------|--------|-------------|
| Cleanup: delete conflicting workflows | 15 min | Remove `myapps-prod-deploy.yml` and `myapps-pr-preview.yml` |
| C1: `--force` in release build | 5 min | One flag change in `release.yml` |
| C5: Env validation Vite plugin | 1 hr | Create plugin + wire into all app configs |
| C11: Turbo cache env hashing | 15 min | Update `turbo.json` |
| C7: Version visibility | 1 hr | Build-info plugin + version.json in composite-deploy |
| C4: Staging + gated promotion | 2 hr | Split release.yml into stage/approve/promote |
| C8: Rollback runbook + auto-rollback | 1 hr | Create runbook + add rollback step to release.yml |

**Total P0 effort:** ~6 hours

### P1: Validation and Previews (items C2, C3, C6, C9)

**Goal:** Every PR gets a preview. Staging gets smoke-tested. Errors are observed.

| Task | Effort | Description |
|------|--------|-------------|
| C2: Deduplicate preview workflows | 30 min | Already mostly done by P0 cleanup |
| C3: Persistent staging channel | 30 min | Already mostly done by P0 C4 |
| C6: Smoke test script + CI integration | 2 hr | Create `smoke-test.mjs` + wire into release.yml |
| C9: Sentry setup | 2 hr | Add Sentry SDK, source map upload, alerting |

**Total P1 effort:** ~5 hours

### P2: Polish (items C10, C12)

**Goal:** Secrets have a proper home. Changesets are enforced.

| Task | Effort | Description |
|------|--------|-------------|
| C10: Encrypted env for local dev | 1 hr | Create `setup-env.sh` + encrypted env file |
| C12: Changeset enforcement in CI | 30 min | Add changeset status check to ci.yml |

**Total P2 effort:** ~1.5 hours

---

## Risks and Tradeoffs

| Risk | Mitigation | Residual |
|------|-----------|----------|
| **GitHub Actions minutes** (free tier: 2000 min/month) | Turbo caching in CI/preview (not release). Affected-only builds on PRs. | Monitor usage monthly. At current PR volume (~10/month), well within free tier. |
| **Firebase preview channel quota** | 25 active preview channels (Spark/Blaze). PR channels expire after 7 days. Staging is 1 persistent channel. | At current PR volume, no risk. If exceeded, reduce expiry to 3 days. |
| **Sentry free tier** (5k errors/month) | Only instrument production builds. Sample rate 1.0 initially, reduce if volume grows. | If exceeded, drop sample rate to 0.1 or switch to Firebase Performance (free). |
| **Build time increase** from `--force` | ~2-3 min per release build vs ~10s cached. Acceptable for production safety. | Only release builds are uncached. CI/preview still use cache. |
| **Staging approval fatigue** | Keep the approval step lightweight (one click in GitHub UI). Document that approving within 15 min is the norm. | If it becomes a bottleneck, consider auto-approve if all smoke tests pass (future). |
| **Complexity increase** | Three-job workflow is more complex than one-job. Failure modes multiply. | Each job is independently restartable. Deploy runbook covers all failure scenarios. |

---

## Migration Plan

Concrete sequence to move from today's state to the target pipeline without downtime.

**PR 1: Cleanup + Turbo fix (P0, no deploy behavior change)**
- Delete `myapps-prod-deploy.yml`
- Delete `myapps-pr-preview.yml`
- Update `turbo.json` with env hashing (C11)
- Add env validation Vite plugin (C5)
- Add `--force` to release build (C1)

**PR 2: Version visibility (P0)**
- Create `build-info.ts` Vite plugin (C7)
- Add `version.json` generation to `composite-deploy.sh` (C7)

**PR 3: Staging + gated promotion (P0)**
- Restructure `release.yml` into 3 jobs: build-stage, approve, deploy-prod (C3, C4)
- Add auto-rollback step (C8)
- Create `architecture/deploy-runbook.md` (C8)

**PR 4: Smoke tests (P1)**
- Create `scripts/smoke-test.mjs` (C6)
- Wire into release.yml staging + production jobs (C6)

**PR 5: Observability (P1)**
- Add Sentry SDK to apps (C9)
- Source map upload in release.yml (C9)
- Configure Sentry alerting

**PR 6: Secrets + changesets (P2)**
- Create `scripts/setup-env.sh` (C10)
- Add changeset check to ci.yml (C12)

Each PR is independently deployable. No PR depends on a later PR. Rolling back any PR does not break the pipeline.

---

## Success Criteria

1. **Zero manual deploy steps for production promotion.** Merge PR, approve in GitHub UI -- that is the entire process. No laptop involved.
2. **100% of production deploys traceable to a git SHA.** `curl https://apps.darkstrawberry.com/version.json` returns the deployed commit hash.
3. **Build fails loudly if any required env var is missing.** No silent production of broken bundles.
4. **Mean time to recovery under 2 minutes.** Auto-rollback on smoke failure, or one-command manual rollback via `workflow_dispatch`.
5. **Every production deploy passes a smoke test before receiving traffic.** Staging smoke gates promotion; post-deploy smoke triggers rollback.

---

## Explicit Non-Goals

- **Multi-region hosting.** Firebase Hosting is already globally CDN-distributed. No additional region configuration needed.
- **Blue-green deployments.** Firebase's atomic deploy model (version swap) is sufficient. Blue-green adds complexity without benefit at this scale.
- **Feature flags.** Valuable but orthogonal to deploy safety. Can be added independently later (Firebase Remote Config is a natural fit).
- **Monorepo restructuring.** The workspace layout works. This plan operates within the existing structure.
- **Automated dependency updates (Dependabot/Renovate).** Useful but not part of deploy pipeline architecture.
- **Custom domain per preview channel.** Firebase preview channels get auto-generated URLs. Custom subdomains are not worth the DNS complexity.
- **Windows CI runners.** All CI runs on `ubuntu-latest`. POSIX scripts are portable but CI does not need Windows.
