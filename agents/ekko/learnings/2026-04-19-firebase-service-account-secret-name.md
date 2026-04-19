# Firebase Service Account Secret Name Mismatch

Date: 2026-04-19

## What happened

`FirebaseExtended/action-hosting-deploy@v0` fails with "Input required and not supplied: firebaseServiceAccount" when the referenced secret exists but is empty. GitHub Actions evaluates an empty secret as an empty string, which the action treats as absent.

## Root cause

Firebase Console auto-generates a secret named `FIREBASE_SERVICE_ACCOUNT_<PROJECT_SUFFIX>` (e.g. `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA`). The workflows were pointing at a manually created `FIREBASE_SERVICE_ACCOUNT` that had no value.

## Fix pattern

Update `firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}` to match the actual populated secret name. Both preview workflows must be updated in sync.

## Diagnostic approach

1. Check `gh run list --workflow=preview.yml` for failures.
2. `gh run view <id> --log-failed` — look for "Input required" or "No currently active project".
3. Cross-reference repo secret names via GitHub UI or `gh api`.
4. If `FIREBASE_SERVICE_ACCOUNT` is empty and `FIREBASE_SERVICE_ACCOUNT_MYAPPS_B31EA` exists, point workflows at the latter.
