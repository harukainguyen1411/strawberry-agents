---
title: Migration plan fact-check — 2026-04-18
date: 2026-04-18
author: yuumi
---

# Migration plan fact-check — 2026-04-18

Scanned:
1. `plans/approved/2026-04-19-public-app-repo-migration.md`
2. `plans/in-progress/2026-04-19-public-app-repo-migration-tasks.md`
3. `plans/approved/2026-04-19-strawberry-agents-companion-migration.md`
4. `plans/in-progress/2026-04-19-strawberry-agents-companion-tasks.md`
5. `assessments/2026-04-18-migration-acceptance-gates.md`

Verification method: live grep against `/Users/duongntd99/Documents/Personal/strawberry/` checkout plus `gh secret list --repo Duongntd/strawberry`.

---

## Summary

- 2 claims WRONG
- 3 claims NOT-FOUND (in live workflows/secrets — see below)
- 17 claims VERIFIED
- 3 claims SKIPPED (Console UI only)

---

## Wrong claims (priority)

### Wrong claim 1: "Firebase CI/CD GitHub App" installs drive Firebase deploys

**Exact quotes from plans:**
- `plans/approved/2026-04-19-public-app-repo-migration.md` line 150: "Install the Firebase CI/CD GitHub App on strawberry-app (Console UI only — no CLI equivalent): Firebase Console → Project Settings → Integrations → GitHub → select `harukainguyen1411/strawberry-app`."
- Same plan, Risk R5 (line 123): "Firebase CI/CD GitHub App installed against strawberry, not strawberry-app → prod deploys break"
- Same plan, Acceptance criteria §9 (line 375): "Firebase GitHub App is installed on strawberry-app and **not** on strawberry."
- `assessments/2026-04-18-migration-acceptance-gates.md` gates P3-G9 and P3-G10 (lines 126-130): Verify Firebase GitHub App is installed / not installed via `app_slug | contains("firebase")`.

**Expected (per plan):** Firebase deploys are driven by the Firebase CI/CD GitHub App installed from Firebase Console → Integrations.

**Actual:** All four Firebase-deploying workflows use `FirebaseExtended/action-hosting-deploy@v0` with `firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}` (service-account key auth), not the GitHub App OAuth flow. No workflow references `firebase-app-hosting` or any GitHub App slug.

```
Grep command: grep -rn 'FirebaseExtended\|firebase-hosting-github-action\|firebase-app-hosting' .github/workflows/
```

```
Grep output:
.github/workflows/myapps-prod-deploy.yml:44:        uses: FirebaseExtended/action-hosting-deploy@v0
.github/workflows/release.yml:67:        uses: FirebaseExtended/action-hosting-deploy@v0
.github/workflows/myapps-pr-preview.yml:62:        uses: FirebaseExtended/action-hosting-deploy@v0
.github/workflows/preview.yml:50:        uses: FirebaseExtended/action-hosting-deploy@v0
```

**Impact:** R5, P3-G9, P3-G10, D4, D8 in the task plan, and the acceptance gate M-G5 are all based on this wrong premise. There is no Firebase GitHub App to reinstall — the migration only needs to re-provision the `FIREBASE_SERVICE_ACCOUNT` secret (and `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA`) into strawberry-app. The Console Integrations step is unnecessary.

**Recommendation:** Delete D4, D8, R5 as written. Replace with: "Verify `FIREBASE_SERVICE_ACCOUNT` and `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA` secrets are provisioned in strawberry-app and that the first workflow run using `FirebaseExtended/action-hosting-deploy@v0` completes successfully." Remove P3-G9 and P3-G10 entirely (no GitHub App to verify). Update M-G5 to: "One green Firebase hosting deploy has run from strawberry-app main using `FIREBASE_SERVICE_ACCOUNT`."

---

### Wrong claim 2: "17 GitHub secrets" to re-provision

**Exact quote from plan:**
- `plans/approved/2026-04-19-public-app-repo-migration.md` line 289: "All 17 secrets."
- Same plan, §6.1 table lists 16 named secrets (AGE_KEY through VITE_FIREBASE_STORAGE_BUCKET) plus `BEE_SISTER_UIDS` flagged with "(per scope note, this secret is called out but not in the current `gh secret list`)."
- `assessments/2026-04-18-migration-acceptance-gates.md` line 109: "output must contain (as a superset) the 17 names: `AGE_KEY`, ..., and (per §6.1 note) `BEE_SISTER_UIDS` if Duong confirmed it's provisioned."

**Expected (per plan):** 17 GitHub secrets, including `BEE_SISTER_UIDS`.

**Actual:** `gh secret list --repo Duongntd/strawberry` returns exactly **16 secrets**. `BEE_SISTER_UIDS` is not a GitHub secret — it is a Firebase Functions parameter defined via `defineString("BEE_SISTER_UIDS", ...)` in `apps/myapps/functions/src/beeIntake.ts` and `apps/myapps/functions/src/index.ts`, configured via `.env` files or the Firebase Functions params system, not via GitHub secrets.

Additionally, two secrets used by live workflows are **not in the plan's 17-secret list at all**:
- `DISCORD_RELAY_WEBHOOK_URL` — used by `myapps-prod-deploy.yml`, `release.yml`, `myapps-pr-preview.yml`, `preview.yml`
- `DISCORD_RELAY_WEBHOOK_SECRET` — used by the same four workflows

These are currently **not provisioned** in the repo (not in `gh secret list` output) but are referenced in workflows. They will need to be provisioned in strawberry-app for those workflows to function.

```
Grep command: grep -rn 'DISCORD_RELAY_WEBHOOK' .github/workflows/ .github/scripts/
```

```
Grep output (first 6 lines):
.github/workflows/myapps-prod-deploy.yml:55:          DISCORD_RELAY_WEBHOOK_URL: ${{ secrets.DISCORD_RELAY_WEBHOOK_URL }}
.github/workflows/myapps-prod-deploy.yml:56:          DISCORD_RELAY_WEBHOOK_SECRET: ${{ secrets.DISCORD_RELAY_WEBHOOK_SECRET }}
.github/workflows/release.yml:84:          DISCORD_RELAY_WEBHOOK_URL: ${{ secrets.DISCORD_RELAY_WEBHOOK_URL }}
.github/workflows/release.yml:85:          DISCORD_RELAY_WEBHOOK_SECRET: ${{ secrets.DISCORD_RELAY_WEBHOOK_SECRET }}
.github/workflows/myapps-pr-preview.yml:74:          DISCORD_RELAY_WEBHOOK_URL: ${{ secrets.DISCORD_RELAY_WEBHOOK_URL }}
.github/workflows/myapps-pr-preview.yml:75:          DISCORD_RELAY_WEBHOOK_SECRET: ${{ secrets.DISCORD_RELAY_WEBHOOK_SECRET }}
```

**Recommendation:** The secret count is 16, not 17. Remove `BEE_SISTER_UIDS` from the GitHub secrets re-provision list; note it is a Firebase Functions param configured separately. Add `DISCORD_RELAY_WEBHOOK_URL` and `DISCORD_RELAY_WEBHOOK_SECRET` to the re-provision list — total becomes 18 secrets if those are provisioned, or 16 if they are intentionally absent (workflows skip Discord notify when unset). Gate P3-G3 and §6.1 table need updating.

---

## Not-found claims

### Not-found 1: `CF_API_TOKEN` and `CF_ACCOUNT_ID` for landing deploys

**Exact quote from plan:**
- `plans/approved/2026-04-19-public-app-repo-migration.md` §6.1 table, row: "`CF_ACCOUNT_ID`, `CF_API_TOKEN` | Cloudflare dashboard | For landing deploys"

**Expected:** Landing is deployed to Cloudflare via wrangler, requiring these secrets in workflows.

**Actual:** `landing-prod-deploy.yml` deploys via `npx firebase-tools@latest deploy --only hosting --project myapps-b31ea` using `FIREBASE_SERVICE_ACCOUNT`. No wrangler, no Cloudflare action, no CF_* reference anywhere in `.github/workflows/` or `apps/landing/`. `CF_API_TOKEN` and `CF_ACCOUNT_ID` are provisioned as repo secrets but have zero usage in any workflow or app code (only a bare mention in `mcps/cloudflare/scripts/start.sh` which is an MCP tool config, not a deploy workflow).

```
Grep command: grep -rln 'CF_API_TOKEN\|CF_ACCOUNT_ID\|wrangler' .github/workflows/ apps/landing/
Result: (no output)
```

**Verdict:** NOT-FOUND in workflows. The secrets exist in the repo but appear unused by any current workflow. The plan's description of their purpose ("for landing deploys") does not match the actual deploy mechanism. Either these secrets are leftover from a past Cloudflare Pages experiment, or they are intended for a future use not yet wired up.

**Recommendation:** Remove "for landing deploys" description from §6.1 table. Flag CF_* secrets for Duong to confirm whether they are needed at all before re-provisioning in strawberry-app. Do not assume they are required for a green first deploy.

---

### Not-found 2: `GCP_SA_KEY_PROD` and `GCP_SA_KEY_STAGING` for Cloud Run / Functions deploy

**Exact quote from plan:**
- `plans/approved/2026-04-19-public-app-repo-migration.md` §6.1 table, row: "`GCP_SA_KEY_PROD`, `GCP_SA_KEY_STAGING` | GCP IAM → Service Accounts → new key | Cloud Run / Functions deploy"

**Expected:** Workflows deploy to Cloud Run or GCP Functions using these service account keys.

**Actual:** No workflow in `.github/workflows/` references `GCP_SA_KEY_PROD`, `GCP_SA_KEY_STAGING`, `google-github-actions/deploy-cloudrun`, or any `gcloud run` command. These secrets exist in the repo but have no workflow consumers. Cloud Functions deploys use `FIREBASE_SERVICE_ACCOUNT` via firebase-tools, not GCP SA keys directly.

```
Grep command: grep -rn 'GCP_SA_KEY\|google-github-actions\|gcloud run' .github/workflows/
Result: (no output)
```

**Verdict:** NOT-FOUND in workflows. Same situation as CF_*: secrets provisioned but no current workflow uses them.

**Recommendation:** Remove "Cloud Run / Functions deploy" description from §6.1 table. Flag for Duong to confirm whether Cloud Run is a future target before re-provisioning. Do not assume they are required for a green first deploy in strawberry-app.

---

### Not-found 3: `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA` as a distinct used secret

**Exact quote from plan:**
- `plans/approved/2026-04-19-public-app-repo-migration.md` §6.1: "`FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA` | Firebase console (myapps project — ID in `apps/myapps/firebase.json`) | myapps functions deploy"

**Expected:** A separate service account secret for the myapps project is used in workflows alongside `FIREBASE_SERVICE_ACCOUNT`.

**Actual:** `grep -rn 'FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA' .github/workflows/` returns no output. All myapps workflow steps use `secrets.FIREBASE_SERVICE_ACCOUNT`. The secret is provisioned in the repo but not referenced by any current workflow.

**Verdict:** NOT-FOUND in live workflows. The secret exists but is not currently consumed. `apps/myapps/firebase.json` confirms the project ID is `myapps-b31ea` (via the Firebase hosting site `myapps-b31ea`), but the SA secret for it goes unused in CI today.

**Recommendation:** Note in the re-provision list that this secret may be wired up in a future workflow step but is not required for a green first deploy from strawberry-app. Duong should confirm before treating it as a hard dependency.

---

## Verified claims (appendix)

All checks run against the live strawberry checkout at `/Users/duongntd99/Documents/Personal/strawberry/`.

| # | Claim | Source | Verdict |
|---|-------|--------|---------|
| V1 | `FIREBASE_SERVICE_ACCOUNT` used in workflows via `FirebaseExtended/action-hosting-deploy@v0` | 4 workflow files | VERIFIED |
| V2 | 14 workflows exist in `.github/workflows/` | `ls .github/workflows/*.yml \| wc -l` = 14 | VERIFIED |
| V3 | `.github/scripts/` contains `notify-discord-preview.js` and `notify-discord-shipped.js` | `ls .github/scripts/` | VERIFIED |
| V4 | `scripts/setup-branch-protection.sh` exists | `test -f` | VERIFIED |
| V5 | `scripts/verify-branch-protection.sh` exists | `test -f` | VERIFIED |
| V6 | `scripts/setup-github-labels.sh` exists | `test -f` | VERIFIED |
| V7 | `scripts/setup-discord-channels.sh` exists | `test -f` | VERIFIED |
| V8 | `scripts/plan-promote.sh`, `plan-publish.sh`, `plan-unpublish.sh`, `plan-fetch.sh`, `_lib_gdoc.sh` exist (private-repo-only) | `test -f` each | VERIFIED |
| V9 | `scripts/safe-checkout.sh` exists | `test -f` | VERIFIED |
| V10 | `scripts/evelynn-memory-consolidate.sh`, `list-agents.sh`, `new-agent.sh`, `lint-subagent-rules.sh`, `strip-skill-body-retroactive.py`, `hookify-gen.js` exist (private-only) | `test -f` each | VERIFIED |
| V11 | `scripts/google-oauth-bootstrap.sh`, `scripts/setup-agent-git-auth.sh` exist (private-only) | `test -f` each | VERIFIED |
| V12 | `scripts/deploy-discord-relay-vps.sh`, `scripts/composite-deploy.sh`, `scripts/scaffold-app.sh`, `scripts/seed-app-registry.sh`, `scripts/migrate-firestore-paths.sh`, `scripts/vps-setup.sh`, `scripts/health-check.sh` exist (public) | `test -f` each | VERIFIED |
| V13 | `scripts/gh-audit-log.sh`, `scripts/gh-auth-guard.sh` exist | `test -f` each | VERIFIED |
| V14 | 16 secrets exist in `Duongntd/strawberry` (AGE_KEY, AGENT_GITHUB_TOKEN, BOT_WEBHOOK_SECRET, CF_ACCOUNT_ID, CF_API_TOKEN, FIREBASE_SERVICE_ACCOUNT, FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA, GCP_SA_KEY_PROD, GCP_SA_KEY_STAGING, VITE_FIREBASE_API_KEY, VITE_FIREBASE_APP_ID, VITE_FIREBASE_AUTH_DOMAIN, VITE_FIREBASE_MEASUREMENT_ID, VITE_FIREBASE_MESSAGING_SENDER_ID, VITE_FIREBASE_PROJECT_ID, VITE_FIREBASE_STORAGE_BUCKET) | `gh secret list` | VERIFIED |
| V15 | `landing-prod-deploy.yml` deploys via `firebase-tools` using `FIREBASE_SERVICE_ACCOUNT` (no Cloudflare) | workflow file | VERIFIED |
| V16 | `BEE_SISTER_UIDS` is a Firebase Functions `defineString` param, not a GitHub secret | `grep` in `apps/myapps/functions/src/beeIntake.ts` and `index.ts` | VERIFIED |
| V17 | `apps/myapps/firebase.json` project references `myapps-b31ea` (site name matches secret name) | `firebase.json` contents | VERIFIED |

---

## Skipped claims

| # | Claim | Reason |
|---|-------|--------|
| S1 | Firebase CI/CD GitHub App is or is not currently installed on `Duongntd/strawberry` | Requires GitHub Console UI or authenticated `gh api /repos/Duongntd/strawberry/installations` — cannot verify without elevated API token. Mark for Duong to check manually. |
| S2 | GCP project IDs (non-secret metadata) match what GCP IAM shows | Requires GCP Console or `gcloud` CLI authenticated as Duong's service account. |
| S3 | Secret values (e.g. `FIREBASE_SERVICE_ACCOUNT` JSON, `AGE_KEY`) are correct and rotatable | Rule 6 — no decryption. Duong verifies manually. |
