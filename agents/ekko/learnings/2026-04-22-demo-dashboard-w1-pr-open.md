# 2026-04-22 — demo-dashboard W1 PR open

## Task
Open PR for feat/demo-dashboard-split (W1 scaffold) in missmp/company-os.

## What was verified
- `git log origin/feat/demo-dashboard-split --oneline` confirmed all 3 commits present on origin before PR creation. No push needed.
- `pytest tools/demo-dashboard/tests/ -q` from worktree root: `1 passed in 0.22s`.

## PR
- Number: #65
- URL: https://github.com/missmp/company-os/pull/65
- Title: `feat(demo-dashboard): W1 scaffold — new Cloud Run service skeleton`
- Base: `main` @ `afdf1a8`
- Head: `feat/demo-dashboard-split`

## Patterns
- Worktree for this branch at `~/Documents/Work/mmp/workspace/company-os-demo-dashboard-split/`
- `gh pr create` from worktree root picks up the correct remote and head branch automatically.
- Rule 16 (QA report) is exempt for API-only PRs with no UI surface.
- Reviewer dispatch (Senna/Lucian) is a separate step via `scripts/reviewer-auth.sh` — not done here per task instructions.
