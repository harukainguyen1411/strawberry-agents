# Ekko Last Session — 2026-04-19

- Diagnosed `firebaseServiceAccount` input error on PRs #25/#26/#28 preview deploys.
- Root cause: `FIREBASE_SERVICE_ACCOUNT` secret exists by name but stored value is empty/zero-byte — runner drops empty secrets from `with:` log echo, `action-hosting-deploy@v0` throws "Input required and not supplied".
- Both workflow files (`preview.yml` L53, `myapps-pr-preview.yml` L65) reference the correct secret name — no workflow change needed.

Open threads:
- Duong must re-paste the Firebase service account JSON into `FIREBASE_SERVICE_ACCOUNT` on `harukainguyen1411/strawberry-app` (delete + recreate secret with actual JSON value).
- PR #26 lockfile desync (vitest pin) is a separate unrelated failure.
