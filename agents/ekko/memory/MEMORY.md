# Ekko Memory

## Persistent Context

- Working tree is shared with other agents — always use explicit `git add <specific-files>`, never `git add -A` or `git add .`
- Commits from this agent: use `chore:` or `ops:` prefix for non-code infra work
- `scripts/safe-checkout.sh` required for any branch work — never raw `git checkout`
- `tools/decrypt.sh` required for decryption — never raw `age -d`
- Pushing `.github/workflows/` requires `workflow` OAuth scope. Duongntd's token (refreshed 2026-04-19) HAS `workflow` scope. harukainguyen1411 is for PR reviews only, not pushes.
- `secrets/encrypted/github-triage-pat.age` holds the Duongntd classic PAT (repo+workflow). Repo secret name: `AGENT_GITHUB_TOKEN` on `harukainguyen1411/strawberry-agents`.
- `harukainguyen1411/strawberry-app` cloned at `~/Documents/Personal/strawberry-app`.
- Firebase preview secret: `FIREBASE_SERVICE_ACCOUNT` EXISTS on the repo but value is EMPTY — Duong must delete + re-add with actual JSON from Firebase console.
- E2E `auth-local-mode` failures are pre-existing app bugs (heading not visible), not workflow issues.
- PR #38 (`fix/router-lint-errors`) fixes `no-unused-expressions` in task-list + read-tracker routers — unblocks PRs #29/#32/#33.
- `composite-deploy.sh` outputs to `deploy/` not `dist/`. Any workflow copying `apps/myapps/firebase.json` to repo root must patch `"public": "dist"` → `"public": "deploy"` via sed. PR #25 fix commit: 4871740.
- Required checks for `main` branch: xfail-first, regression-test, unit-tests, Playwright E2E, QA report present. `E2E tests (Playwright / Chromium)` is NOT required — pre-existing auth-local-mode heading bug.

## Sessions

- 2026-04-17: Dependabot B5/B7 vitest3 upgrade
- 2026-04-18: TDD hooks + CI wiring; Guard 4 allowlist fix; lockfile sync; ulid lockfile fix; migration dry-run + Phase 1 real run + P3.1 push + P3.9 smoke test; phase-0 PR audit; F4 age-encrypt env bundles; git hygiene sweep; statusline setup + idle-time + ci/pr/quota strip; A3 strawberry-agents push
- 2026-04-19: P1.3 env ciphertext; A4 operational surface sync; O4.1-O4.3 orianna memory-audit; PR #25/#26/#28 CI diagnosis rounds 1+2 + fixes applied; plan-promote tests-dashboard bypass; Firebase preview secret root cause diagnosis (empty value, not missing name); promote orianna-role-redesign ADR to approved; PR #25 fix: copy .firebaserc to root (a303dd6); PR #26 fix: lockfile regen (99841bc); PR #28 fix: explicit myapps build before composite-deploy (e9650bb)

## Archive Note

Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention through 2026-07-18).
