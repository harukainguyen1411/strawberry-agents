# Migration P3 Non-Interactive Steps — Learnings

Date: 2026-04-18
Session scope: P3.2–P3.7 on harukainguyen1411/strawberry-app

## Key findings

### Branch protection (P3.3)
- setup-branch-protection.sh in the migration tree already accepted $1 (done in P2)
- verify-branch-protection.sh also already accepted $1
- Only setup-github-labels.sh needed patching to accept $1
- The live strawberry scripts/setup-branch-protection.sh still uses `REPO="${REPO:-Duongntd/strawberry}"` (env-based, no $1) — only the migration tree version was parametrized
- `gh api PUT .../branches/main/protection` returns the full protection object on success (not 204) — can parse inline

### Dependabot endpoints (P3.2)
- vulnerability-alerts → 204 = enabled
- automated-security-fixes → 200 = enabled (not 204 — different endpoint)

### FIREBASE_SERVICE_ACCOUNT vs FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA (P3.5/P3.6)
- Only `FIREBASE_SERVICE_ACCOUNT` is used across all 6 workflows
- `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA` appears only in docs/delivery-pipeline-setup.md (an old checklist)
- Safe to set only FIREBASE_SERVICE_ACCOUNT; the _MYAPPS_B31EA variant is an orphan

### BEE_SISTER_UIDS (P3.6)
- Firebase Functions parameter via `defineString()`, not a GH secret
- Default is `""` — functions run but Bee auth is disabled if not set
- Must be provisioned in Firebase Console for production use
- No GH Actions reference anywhere in workflows

### CI lint wiring (P3.7)
- Created standalone lint-slugs.yml rather than adding to ci.yml — cleaner separation, job name is `check-no-hardcoded-slugs`
- check-no-hardcoded-slugs.sh runs fine in a clean checkout (no npm deps needed)
- actions/checkout@v4 (not v6 — that's what ci.yml uses but v4 is current stable)
  - Note: ci.yml in the migration tree uses @v6 which doesn't exist yet (might fail) — separate issue, not in scope

### Bash sandbox reminder
- python3 -c pattern for JSON parsing when jq pipe to head would SIGPIPE
