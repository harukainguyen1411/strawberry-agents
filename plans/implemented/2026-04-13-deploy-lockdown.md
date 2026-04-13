---
status: implemented
owner: shen
created: 2026-04-13
---

# Deploy Lockdown — One Pipeline, One Key, CI Only

## Goal

Make production deploys impossible from any laptop. Push-to-main → GitHub Actions is the **only** path. Everything else fails because the credentials do not exist on the laptop.

No wrapper scripts. No alias tricks. No CLAUDE.md rule. No emergency override. The key itself is the gate.

## Motivating incident

2026-04-13 — `npm run deploy` from a laptop shipped a broken bundle to prod in ~30 seconds, bypassing the 10 existing GitHub Actions workflows. Root cause: the laptop had full Firebase prod credentials.

## Scope

1. **Rotate** the Firebase Hosting service account so any existing copy (local, in a backup, in a browser downloads folder) is dead.
2. **Upload** the new key to GitHub Actions secret `FIREBASE_SERVICE_ACCOUNT` (already the name used by `release.yml`).
3. **Delete** every local copy of a prod SA or prod-scoped Firebase user token:
   - `secrets/firebase-hosting-sa-myapps.json` — delete
   - `~/.config/configstore/firebase-tools.json` (CLI refresh token) — `firebase logout` removes it
   - Any other `*firebase*service*account*.json` anywhere on disk — find + delete
4. **Document** the result in one short file: `architecture/deploy-runbook.md`.

That's it. Five bullets, one file created, two files deleted.

## Steps (for Shen)

1. **Verify GH Actions workflows already consume `FIREBASE_SERVICE_ACCOUNT` as a secret.** `grep -rn "FIREBASE_SERVICE_ACCOUNT" .github/workflows/` — expect hits in `release.yml`, `preview.yml`, `landing-prod-deploy.yml`, `myapps-prod-deploy.yml`. Do NOT change workflow YAML.
2. **Have Duong rotate the SA key** (manual — Shen provides the exact clicks):
   - Console: https://console.cloud.google.com/iam-admin/serviceaccounts?project=myapps-b31ea
   - Find the service account used by Firebase Hosting (should be named `firebase-adminsdk-*` or `github-action-*`).
   - Keys tab → Add Key → Create new key → JSON → download.
   - Same screen → delete every older key for that SA.
3. **Have Duong upload the new key** to GitHub: `gh secret set FIREBASE_SERVICE_ACCOUNT < path/to/new-key.json` — then delete the file from Downloads.
4. **Delete local SA files:**
   ```bash
   rm -f secrets/firebase-hosting-sa-myapps.json
   find ~ -type f \( -iname "*firebase*service*account*.json" -o -iname "*myapps-b31ea*sa*.json" \) -print -delete
   ```
5. **Log out the Firebase CLI:**
   ```bash
   firebase logout
   ```
6. **Write `architecture/deploy-runbook.md`** — one page, covering:
   - How prod deploys work today (push main → Actions → Firebase Hosting).
   - There is no other path. The SA lives only in `FIREBASE_SERVICE_ACCOUNT` GitHub secret.
   - Rotation procedure (step 2 + 3 above).
   - If CI is broken and a deploy must happen: rotate a new key, run it once, rotate again — no permanent local copy. This is deliberate friction.

## Acceptance

```bash
# No local SA key
find ~ -type f \( -iname "*firebase*service*account*.json" -o -iname "*myapps-b31ea*sa*.json" \)
# Expected: zero lines

# Firebase CLI can't touch prod
firebase projects:list 2>&1 | grep -c myapps-b31ea
# Expected: 0

# GH Actions secret present
gh secret list | grep -c '^FIREBASE_SERVICE_ACCOUNT'
# Expected: 1

# One clean push triggers the real pipeline
git commit --allow-empty -m "chore: smoke test deploy lockdown" && git push
gh run list --workflow myapps-prod-deploy.yml --limit 1
# Expected: one run, triggered by the push, status success
```

## Out of scope

- Neutering `npm run deploy` — harmless if run, it will fail at `firebase deploy` because there's no auth.
- Wrapper scripts, hooks, aliases — redundant once the key is gone.
- CLAUDE.md rule — the system enforces this, not a doc.
- Emergency override env var — if you need to deploy in an emergency, rotate a key, use it, rotate it again. Deliberate friction is the point.
- Swain's broader pipeline plan (staging channel, smoke tests, version.json) — tracked separately in `plans/proposed/2026-04-13-deployment-pipeline-architecture.md`.
