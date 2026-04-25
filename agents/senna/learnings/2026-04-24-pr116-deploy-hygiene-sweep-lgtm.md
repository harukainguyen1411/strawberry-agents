---
date: 2026-04-24
pr: missmp/company-os#116
repo: missmp/company-os
base: feat/demo-studio-v3
head: fix/deploy-hygiene-sweep
verdict: LGTM (comment)
surface: 8 files, +140 / -6
---

# PR #116 — Wave C deploy hygiene sweep

## What it did
- Added dirty-tree guard (`git status --porcelain` + `FORCE_DIRTY=1` escape hatch) and `--labels=git-sha=$(git rev-parse HEAD)` to 6 peer-tool deploy.sh scripts under `tools/` (demo-dashboard, demo-factory, demo-preview, demo-studio-mcp, demo-studio-v3, demo-verification).
- TDD-first: xfail shell test at `tools/_scripts/test_deploy_hygiene.sh` landed in commit 1 (`4ef87cd`), then impl in commit 2 (`f5dbb7f`), then CI workflow in commit 3 (`6ca1ed0`).
- CI workflow `tdd-gate-deploy-hygiene.yml` triggers on push-to-branch and PR; runs the shell test as a single-step job.

## What I verified locally
Cloned the PR branch shallow and replayed each commit's tree to run the test:
- At xfail commit: exit 1, 12 missing-token lines (6×2), matching the header comment's prediction.
- At impl commit: exit 0, success message.
This is the cleanest way to validate "xfail fails first, impl flips it green" when CI didn't exist yet at the xfail commit. Worth reusing.

## Findings
All non-blocking. Posted as comment (per new work-scope protocol):
1. `demo-studio-mcp/deploy.sh` uses unquoted `${GIT_SHA}` inside the `GCLOUD_CMD` string, vs quoted in the other five. Cosmetic asymmetry; functionally correct because it's inside an already-quoted heredoc-style string.
2. Test is grep-level — won't catch "token in comment, not in condition." Proportionate; stronger follow-up is mock-gcloud exec + dirtied-tree assertions.
3. `push` trigger is scoped to the feature branch → invariant not enforced on main post-merge. Intentional for a transient gate, but flag for promotion to required check once pattern is accepted.

## Protocol update noted
Work-scope reviews now post as **PR comments** (not GitHub Reviews) via `gh pr comment --repo missmp/company-os -F body-file`, authenticating as `duongntd99` via `gh auth switch --user duongntd99`. Duong approves manually from `harukainguyen1411`. This differs from the personal-scope flow (reviewer-auth.sh + --lane senna). Update memory accordingly.

## Signature
Used `-- reviewer` (neutral) — correct for work-scope per CLAUDE.md anonymity rule.

## Review URL
https://github.com/missmp/company-os/pull/116#issuecomment-4311603208
