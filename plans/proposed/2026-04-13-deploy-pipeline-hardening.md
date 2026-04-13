---
status: proposed
owner: swain
created: 2026-04-13
tags: [incident-response, deploy, dark-strawberry]
---

# Deploy Pipeline Hardening

## Incident Summary

**Date:** 2026-04-13
**Duration:** ~1 hour from user report to recovery
**Impact:** `apps.darkstrawberry.com` rendered a blank page in production. All users affected.

**Timeline:**
1. A caching-fix branch was merged and deployed. The fix modified `firebase.json` Cache-Control headers.
2. `npm run build` ran via Turborepo. Turbo reported `Cached: 6 cached, 6 total` -- every app used a cached dist/.
3. The cached bundles were produced during an earlier build where `VITE_FIREBASE_*` environment variables were not loaded (likely a CI or local environment mismatch).
4. The deployed bundle threw `Missing Firebase configuration` at mount. The SPA rendered blank.
5. Fix: `rm -rf .turbo apps/*/dist && npm run build && redeploy`. Full cache bust + rebuild + redeploy.

**Root cause:** Turborepo's cache key does not incorporate Vite environment variables or `.env*` file contents. A build artifact produced without required env vars was cached and reused across subsequent deploys without detection.

**Systemic gaps identified:**
- No build-time validation of required environment variables.
- Turbo cache keys blind to env var changes.
- No post-deploy smoke test -- a completely broken page deploys silently.
- No documented rollback procedure.

---

## Mitigations

### M1: Post-Deploy Smoke Test (P0 -- ship today)

**Rationale:** The single highest-leverage fix. Even if a bad bundle ships, a smoke test catches it within seconds of deploy and prevents silent failures.

**Implementation steps:**

1. Create `scripts/post-deploy-smoke.sh` (POSIX-portable bash).
2. The script accepts an optional `--sites` argument; defaults to `https://darkstrawberry.com https://apps.darkstrawberry.com`.
3. For each site, use `npx playwright` (or a lightweight Node script under `scripts/smoke-test.mjs`) to:
   - Navigate to the URL.
   - Wait for `networkidle`.
   - Assert the page `<title>` is not empty and not the browser default.
   - Assert a key DOM marker is present (e.g., `#app` or `#root` contains child elements).
   - Collect all `console.error` messages; fail if any are present.
   - Timeout after 30 seconds per site.
4. On failure: print a red banner (`\033[1;31m`) with the failing URL, the assertion that failed, and the console errors. Exit non-zero.
5. On success: print a green confirmation line per site.
6. Integrate into `scripts/composite-deploy.sh`: after `firebase deploy` succeeds, call `scripts/post-deploy-smoke.sh`. If smoke fails, print the rollback command (see M4) and exit non-zero.

**Acceptance test:**
- Temporarily break a bundle (e.g., inject a `throw` at the top of main.ts), deploy, confirm smoke test catches it and prints the red banner.
- Deploy a working bundle, confirm smoke test passes green.

---

### M2: Env Validation at Build Time (P0 -- ship today)

**Rationale:** Fail the build loudly if required Firebase config is missing, rather than producing a bundle that will crash at runtime.

**Implementation steps:**

1. Create a shared Vite plugin at `packages/shared/vite-plugins/env-validation.ts` (or inline in each app's `vite.config.ts` if a shared package doesn't exist yet).
2. The plugin hooks into `configResolved` and checks that the following env vars are defined and non-empty:
   - `VITE_FIREBASE_API_KEY`
   - `VITE_FIREBASE_AUTH_DOMAIN`
   - `VITE_FIREBASE_PROJECT_ID`
   - `VITE_FIREBASE_STORAGE_BUCKET`
   - `VITE_FIREBASE_MESSAGING_SENDER_ID`
   - `VITE_FIREBASE_APP_ID`
3. If any are missing, throw an error with a clear message: `Build aborted: missing required env var VITE_FIREBASE_API_KEY. Ensure .env or .env.local is present.`
4. Each app that uses Firebase adds this plugin to its `vite.config.ts`.

**Acceptance test:**
- Remove `.env.local`, run `npm run build`. Build should fail with the missing-var error.
- Restore `.env.local`, run `npm run build`. Build should succeed.

---

### M3: Turbo Cache Key Includes Env Hash (P1 -- this week)

**Rationale:** Even with M2, Turbo could serve a stale cached bundle if the env vars changed between builds (e.g., switching Firebase projects). The cache key must reflect env state.

**Implementation steps:**

1. In `turbo.json`, add `globalDotEnv` and/or `dotEnv` fields to ensure `.env*` files are included in the cache hash. Example:

   ```json
   {
     "globalDotEnv": [".env", ".env.local"],
     "pipeline": {
       "build": {
         "dotEnv": [".env", ".env.local", ".env.production", ".env.production.local"],
         "env": [
           "VITE_FIREBASE_API_KEY",
           "VITE_FIREBASE_AUTH_DOMAIN",
           "VITE_FIREBASE_PROJECT_ID",
           "VITE_FIREBASE_STORAGE_BUCKET",
           "VITE_FIREBASE_MESSAGING_SENDER_ID",
           "VITE_FIREBASE_APP_ID"
         ]
       }
     }
   }
   ```

2. The `env` array tells Turbo to include these specific environment variable values in the cache hash. The `dotEnv` array tells Turbo to include the file contents of those dotenv files in the hash.
3. After updating, verify: change a value in `.env.local`, run `npm run build`, confirm Turbo reports a cache miss for affected apps.

**Acceptance test:**
- Run `npm run build` twice with identical env. Second run should be fully cached.
- Change `VITE_FIREBASE_API_KEY` in `.env.local`, run `npm run build`. Should report cache miss.

---

### M4: Rollback Playbook (P1 -- this week)

**Rationale:** When a bad deploy is detected, recovery should be a single command, not a rebuild-and-redeploy cycle.

**Implementation steps:**

1. Add a section to `architecture/deploy-runbook.md` (create if it doesn't exist) documenting:

   ```
   ## Emergency Rollback

   Firebase Hosting supports instant rollback to the previous deploy:

     firebase hosting:rollback --site darkstrawberry
     firebase hosting:rollback --site apps-darkstrawberry

   This reverts to the previous release. No rebuild needed. Takes ~10 seconds.

   To rollback to a specific version:
     firebase hosting:releases:list --site darkstrawberry
     firebase hosting:rollback --site darkstrawberry --release <release-id>
   ```

2. In `scripts/post-deploy-smoke.sh`, when the smoke test fails, print:
   ```
   DEPLOY FAILED SMOKE TEST. To rollback:
     firebase hosting:rollback --site <site>
   ```

**Acceptance test:**
- Deploy a known-good version. Deploy a broken version. Run `firebase hosting:rollback`. Confirm the site is restored.

---

### M5: Clean-Build for Release Deploys (P2 -- later)

**Rationale:** For production deploys specifically, a `--force` (no-cache) build eliminates the entire class of stale-cache bugs. The tradeoff is slower builds (~2-3 min vs ~10s cached).

**Implementation steps:**

1. In `scripts/composite-deploy.sh`, add a `--clean` flag that runs `rm -rf .turbo apps/*/dist` before `npm run build`.
2. Document that production deploys should use `--clean` (or always default to it for the `deploy` script).
3. Alternatively, add a `build:release` script in `package.json` that runs `turbo run build --force`.
4. Decision point: whether `--clean` is the default for all deploys or opt-in. Given the small scale of the monorepo (6 apps, <3 min build), defaulting to `--clean` for deploy is acceptable.

**Acceptance test:**
- Run `scripts/composite-deploy.sh --clean`. Confirm no turbo cache is used. Confirm all apps rebuild from scratch.

---

## Priority Summary

| ID | Mitigation | Priority | Effort |
|----|-----------|----------|--------|
| M1 | Post-deploy smoke test | P0 | ~2 hours |
| M2 | Env validation at build time | P0 | ~30 min |
| M3 | Turbo cache key includes env hash | P1 | ~30 min |
| M4 | Rollback playbook | P1 | ~30 min |
| M5 | Clean-build for release deploys | P2 | ~30 min |

---

## What This Would Have Caught

Mapping each mitigation to the 2026-04-13 incident:

- **M1 (Smoke test):** Would have caught the blank page immediately after deploy. The smoke script would have detected zero child elements in `#app` and the `Missing Firebase configuration` console error. Deploy would have exited non-zero with a red banner and rollback instructions. Time-to-detection: ~30 seconds instead of ~30 minutes (user report).

- **M2 (Env validation):** Would have prevented the bad bundle from ever being built. The Vite plugin would have thrown `Build aborted: missing required env var VITE_FIREBASE_API_KEY` during the original build that produced the poisoned cache entry. The incident would never have occurred.

- **M3 (Turbo cache key):** Would have prevented the stale cache from being reused. Even if the original build somehow produced a bad bundle, subsequent builds with correct env vars would have been cache misses, forcing a fresh build with the correct configuration.

- **M4 (Rollback playbook):** Would have reduced recovery time from ~1 hour (diagnose + cache bust + rebuild + redeploy) to ~30 seconds (`firebase hosting:rollback`).

- **M5 (Clean build):** Would have eliminated the cache reuse entirely. A forced rebuild would have either succeeded (with env vars present) or failed at build time (with M2 catching missing vars).

**Defense in depth:** M2 prevents the bad build. M3 prevents the bad cache. M5 forces fresh builds. M1 catches anything that slips through. M4 enables instant recovery. Any single mitigation would have prevented or shortened this incident; together they make this class of failure structurally impossible.
