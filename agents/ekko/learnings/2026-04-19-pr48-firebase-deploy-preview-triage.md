# PR #48 — Firebase Hosting PR Preview & Deploy Preview Triage

Date: 2026-04-19

## Finding

Both failing checks on PR #48 are pre-existing infrastructure problems, not caused by the e2e.yml edits on the branch.

- **Firebase Hosting PR Preview** (job `Deploy preview channel`): fails with
  `Error: No currently active project.` — firebase.json exists but no `--project`
  flag is passed and no `.firebaserc` active project is set. This same failure
  appears on unrelated Dependabot PRs (e.g. `@eslint/js`, `vue-tsc` bumps).

- **Deploy Preview**: this check name appears as a job inside the TDD Gate workflow
  run — likely a Netlify/Vercel bot that posts a check run independently. It also
  fails on unrelated PRs, confirming pre-existing state.

- Branch protection: classic branch protection returns 404 (not configured);
  rulesets array is empty. Neither check is a required status check.

## Recommendation

Ignore for PR #48 — non-required, pre-existing. Fix the Firebase missing-project
config in a dedicated infra chore PR (add `--project <id>` to the firebase-preview
workflow or create a `.firebaserc`).
