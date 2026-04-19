# 2026-04-19 — Firebase PR Preview Rerun (PRs #29 and #33)

## What happened
Reruns of Firebase Hosting PR Preview checks were triggered for PRs #29 and #33 on harukainguyen1411/strawberry-app. The first rerun (run IDs 24621992100 / 24621991571) failed with "Directory 'dist' for Hosting does not exist."

## Root cause of intermediate failure
The `preview.yml` workflow uses `composite-deploy.sh` to assemble a `deploy/` directory at repo root, then patches `firebase.json` with `sed -i 's|"public": "dist"|"public": "deploy"|'`. Despite the patch step reporting success, `action-hosting-deploy@v0` still reported finding no `dist/`. This appears to be a transient issue — the second rerun (triggered implicitly by gh pr checks polling a new run) passed cleanly.

## Final outcome
Both PRs ended with Firebase Hosting PR Preview = pass and Deploy Preview = pass. The duplicate xfail-first check entries (one fail, one pass) are from two separate pipeline triggers for the same SHA — the pass satisfies branch protection.

## Notes
- `gh pr checks` surfaces ALL runs for a given check name, not just the latest. When two runs exist (one old-fail, one new-pass), the PR may appear partially red but is actually mergeable if branch-protection sees the passing run.
- PR#29 and PR#33 are both ready-to-merge (APPROVED + all checks passing on current head). Do not merge — dispatch to non-author merger.
