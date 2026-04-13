---
status: approved
owner: pyke
created: 2026-04-13
tags: [security, deploy, firebase, ci-cd, lockdown]
---

# Deploy Lockdown — No Production Deploys From Laptops

> Complementary to Swain's pipeline architecture plan (`plans/proposed/2026-04-13-deployment-pipeline-architecture.md`). That plan covers staging, smoke tests, version injection, observability. This plan is narrower: make it structurally impossible to deploy to production from a local machine.

## Motivating Incident

2026-04-13: A local `npm run deploy` built via Turbo (stale cache, missing env vars), then `firebase deploy --only hosting` pushed a broken bundle to production in ~30 seconds. The CI workflows existed but were silently bypassed.

---

## Step 1: Neuter the `deploy` npm Script

**Decision:** Replace with a no-op that prints guidance and exits non-zero. Do NOT delete it (a missing script gives a confusing npm error). Do NOT rename to `deploy:dev` (preview channel deploys belong in CI too — Swain's plan covers this).

**Edit `package.json`** — change the `deploy` script:

```json
"deploy": "echo '!! Local deploy is disabled. Production deploys go through GitHub Actions only. See architecture/deploy-runbook.md' && exit 1"
```

**Why exit 1:** Any script or agent that chains `npm run deploy && firebase deploy` will stop immediately.

---

## Step 2: Revoke Firebase CLI Prod Access From the Laptop

**2a. Log out the Firebase CLI:**

```bash
firebase logout
```

This removes the cached refresh token from `~/.config/configstore/firebase-tools.json`.

**2b. Do NOT re-login with prod credentials locally.** If Duong needs local Firebase access (emulator, Firestore dev), log in to a separate **dev-only Firebase project** — never `myapps-b31ea`.

**2c. CI uses a service account, not a user login.** The service account JSON (`FIREBASE_SERVICE_ACCOUNT`) is already a GitHub Actions secret. Confirm no local copy exists:

```bash
# Verify no local SA file
find ~ -name "*firebase*service*account*" -o -name "*myapps-b31ea*sa*" 2>/dev/null
# If found, delete it
```

**2d. Document in `architecture/deploy-runbook.md`:**

> Local Firebase login is for dev/emulator projects only. The prod project `myapps-b31ea` service account exists exclusively as a GitHub Actions secret (`FIREBASE_SERVICE_ACCOUNT`). Never download it locally.

---

## Step 3: Firebase CLI Wrapper That Blocks Local `deploy`

Create `tools/firebase` — a shell wrapper that intercepts deploy commands and refuses unless running in CI.

**Create `tools/firebase`:**

```bash
#!/usr/bin/env bash
# Wrapper around firebase CLI that blocks production deploys from local machines.
# CI sets FIREBASE_DEPLOY_FROM_CI=1 to bypass this guard.
set -euo pipefail

# Check if this is a deploy command
for arg in "$@"; do
  if [ "$arg" = "deploy" ]; then
    if [ "${FIREBASE_DEPLOY_FROM_CI:-}" != "1" ]; then
      echo "BLOCKED: firebase deploy is not allowed from local machines." >&2
      echo "Production deploys go through GitHub Actions only." >&2
      echo "See architecture/deploy-runbook.md for details." >&2
      echo "" >&2
      echo "If CI is down and you need an emergency deploy, use:" >&2
      echo "  FIREBASE_DEPLOY_FROM_CI=1 firebase deploy ..." >&2
      exit 1
    fi
    break
  fi
done

# Pass through to real firebase CLI
exec npx firebase-tools "$@"
```

```bash
chmod +x tools/firebase
```

**Add a shell alias recommendation** to `architecture/deploy-runbook.md`:

> Recommended: add `alias firebase='tools/firebase'` to your shell profile so the wrapper is always active. The wrapper passes all non-deploy commands through unchanged.

**In CI workflows** (`release.yml`, `preview.yml`), ensure the env var is set:

```yaml
env:
  FIREBASE_DEPLOY_FROM_CI: "1"
```

Note: CI workflows use `FirebaseExtended/action-hosting-deploy` (which calls firebase internally), not the wrapper. The wrapper is defense-in-depth for any direct `firebase deploy` invocations in CI scripts like `composite-deploy.sh`.

---

## Step 4: CI-Only Service Account

**Current state:** `FIREBASE_SERVICE_ACCOUNT` is already a GitHub Actions repository secret. This is correct.

**Verify and document:**

1. Confirm the secret exists: `gh secret list` should show `FIREBASE_SERVICE_ACCOUNT`.
2. No local filesystem copy should exist (verified in Step 2c).
3. **Key rotation procedure** (add to `architecture/deploy-runbook.md`):

> ### Service Account Key Rotation
> 1. Go to Google Cloud Console > IAM > Service Accounts > `firebase-hosting-sa@myapps-b31ea.iam.gserviceaccount.com`
> 2. Create a new JSON key
> 3. Update GitHub Actions secret: `gh secret set FIREBASE_SERVICE_ACCOUNT < new-key.json`
> 4. Delete the old key in Google Cloud Console
> 5. Delete the local `new-key.json` immediately after upload
> 6. Trigger a test deploy via `gh workflow run release.yml` to verify

---

## Step 5: Auditability — Tag Every Deploy With a GitHub Actions Run URL

**Edit the deploy step in `release.yml`** to include a `--message` flag:

```yaml
- name: Deploy to live
  uses: FirebaseExtended/action-hosting-deploy@v0
  with:
    repoToken: ${{ secrets.GITHUB_TOKEN }}
    firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
    channelId: live
    projectId: ${{ vars.FIREBASE_PROJECT_ID }}
    # Note: action-hosting-deploy doesn't support --message directly.
    # Use the description field if available, or add a post-deploy step:

- name: Tag deploy in Firebase
  run: |
    echo "Deploy triggered by: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
    echo "Commit: ${{ github.sha }}"
    echo "Actor: ${{ github.actor }}"
  # This is logged in the workflow run itself. For Firebase release metadata,
  # Swain's version.json (C7) provides the authoritative mapping.
```

**Additionally:** Swain's plan (C7) injects `version.json` with `GITHUB_SHA` and `GITHUB_RUN_ID`. Combined, every production deploy is traceable to exactly one GitHub Actions run. No "surprise" releases.

---

## Step 6: CLAUDE.md Rule 12

**Append to the Critical Rules section in `CLAUDE.md`:**

```markdown
12. **Never run `firebase deploy` from a local machine** — production deploys go through GitHub Actions only. Use `tools/firebase` wrapper locally (it blocks deploy commands). For emergency override when CI is down, set `FIREBASE_DEPLOY_FROM_CI=1` explicitly.
```

---

## Acceptance Tests

Run these after implementation to prove the lockdown works:

```bash
# Test 1: npm run deploy is a no-op
npm run deploy
# Expected: prints "Local deploy is disabled..." message, exits non-zero

# Test 2: tools/firebase blocks deploy
tools/firebase deploy --only hosting --project myapps-b31ea
# Expected: prints "BLOCKED: firebase deploy is not allowed..." exits non-zero

# Test 3: tools/firebase allows non-deploy commands
tools/firebase --version
# Expected: prints firebase-tools version (passes through)

# Test 4: firebase CLI has no prod auth
firebase projects:list 2>&1 | grep -c myapps-b31ea
# Expected: 0 (not authenticated to prod project)

# Test 5: CI secret exists
gh secret list | grep FIREBASE_SERVICE_ACCOUNT
# Expected: shows the secret

# Test 6: CLAUDE.md rule exists
grep -c "Never run.*firebase deploy.*from a local machine" CLAUDE.md
# Expected: 1
```

---

## Emergency Override / Rollback

If GitHub Actions CI is down and production is broken:

1. **Preferred: Firebase console rollback.** Go to Firebase Console > Hosting > Release history > Roll back to previous release. Zero CLI needed.

2. **If a fresh deploy is required:**
   ```bash
   # Explicitly acknowledge you know what you're doing
   export FIREBASE_DEPLOY_FROM_CI=1
   # Authenticate temporarily
   firebase login --no-localhost
   # Build and deploy
   npm run build
   bash scripts/composite-deploy.sh
   firebase deploy --only hosting --project myapps-b31ea --message "EMERGENCY: manual deploy, CI down"
   # IMMEDIATELY log out after
   firebase logout
   ```

3. **Post-incident:** File a note in the deploy runbook documenting why CI was down and what was deployed manually.

---

## Files Changed (Summary for Implementer)

| File | Action |
|------|--------|
| `package.json` | Edit `deploy` script to no-op |
| `tools/firebase` | Create (new file, chmod +x) |
| `CLAUDE.md` | Add rule 12 |
| `architecture/deploy-runbook.md` | Create (deploy procedures, rotation, emergency override) |
| `.github/workflows/release.yml` | Add `FIREBASE_DEPLOY_FROM_CI: "1"` env var, add deploy audit log step |
| `.github/workflows/preview.yml` | Add `FIREBASE_DEPLOY_FROM_CI: "1"` env var |

**Manual action required by Duong (not automatable):**
- Run `firebase logout` on the laptop
- Verify no local SA key files exist
- Optionally add `alias firebase='tools/firebase'` to `~/.zshrc`
