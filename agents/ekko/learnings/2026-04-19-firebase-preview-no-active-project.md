# Learning: Firebase Hosting PR Preview — "No currently active project"

Date: 2026-04-19
Repo: harukainguyen1411/strawberry-app

## Root Cause

The `preview.yml` workflow passes `projectId: ${{ vars.FIREBASE_PROJECT_ID }}` to
`FirebaseExtended/action-hosting-deploy@v0`. The `vars.` namespace is a GitHub
repository *variable* (not a secret). If that variable is unset or empty, the
action receives a blank `projectId`, causing Firebase CLI to error:
"No currently active project."

This is distinct from the secrets used for Vite env vars (VITE_FIREBASE_PROJECT_ID).
Two separate values; both must be set. The `.firebaserc` file at
`apps/myapps/.firebaserc` correctly declares `"default": "myapps-b31ea"` but the
action's `--project` flag (sourced from `vars.FIREBASE_PROJECT_ID`) overrides it
and must also be populated.

## Fix Direction

Set the `FIREBASE_PROJECT_ID` repository variable in
Settings → Secrets and variables → Actions → Variables to `myapps-b31ea`.
