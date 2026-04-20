# TDD Gate Bootstrap — company-os

Date: 2026-04-20

## What was done

Ported the TDD gate from strawberry-app into company-os as PR #45 (branch `chore/tdd-gate-bootstrap`).

Files added:
- `.github/workflows/tdd-gate.yml` — two jobs: xfail-first check, regression-test check
- `.github/pull_request_template.md` — Testing table with xfail SHA + regression test + QA-Report fields
- `.github/branch-protection.json` — requires only the two TDD checks; enforce_admins: false
- `scripts/hooks/pre-push-tdd.sh` — local pre-push enforcement (chmod +x)
- `scripts/install-hooks.sh` — one-shot hook installer

## Rule 2 change

Extended Rule 2 keyword detection to also catch conventional-commit `fix:` and `fix(...)` prefixes, in addition to the original space-bounded keywords (bug, bugfix, regression, hotfix). Both the CI workflow and the pre-push hook were updated consistently.

## Gotchas

- company-os is a subdirectory of the workspace repo but is its own git remote (`missmp/company-os.git`). Always use `git -C /path/to/company-os` to target it.
- The repo was on `feat/demo-studio-v3` with uncommitted changes — needed to stash before switching to main.
- `gh pr create` requires `--head` flag when not run from within the repo directory (or when the cwd is different). Use `--head <branch> --base main --repo owner/repo`.
- No TDD packages are opted in — the gate will be a green no-op until someone adds `"tdd": { "enabled": true }` to a package.json.

## Next steps (not done in this session)

1. Wait for CI to go green on PR #45, then merge.
2. Apply branch protection: `gh api repos/missmp/company-os/branches/main/protection --method PUT --input .github/branch-protection.json`
3. Package-by-package onboarding: add `"tdd": { "enabled": true }` to one active JS package as a pilot.
4. Phase B: unit-tests.yml, pr-lint.yml (QA gate), e2e.yml.
5. Phase C: always-report pattern retrofit for any existing path-filtered workflows.
