# Phase 1 Branch — Merge of main with Rename-vs-Add Conflict

## Date
2026-04-19 (ekko s40)

## Context
PR #62 (`chore/phase1-darkstrawberry-apps-rename`) renamed `apps/myapps/` to
`apps/darkstrawberry-apps/`. PR #61 (T212 fixtures) landed on main *after* #62
was branched, adding files under `apps/myapps/portfolio-tracker/test/fixtures/t212-api/`.

## What Happened
`git merge origin/main` succeeded with no conflicts reported (ort strategy),
but placed the new fixture files at the *old* path `apps/myapps/...` because
git did not detect the rename context across the diverged histories.

## Fix
After the merge commit, manually moved the three fixture files from
`apps/myapps/portfolio-tracker/test/fixtures/t212-api/` to
`apps/darkstrawberry-apps/portfolio-tracker/test/fixtures/t212-api/` via
`git rm` + `git add`, and committed as a fixup. Git then correctly detected
all three as renames (100% similarity).

## Outcome
Branch HEAD: `ff372ed`. Push successful.
PR #62 mergeStateStatus: `BLOCKED` (needs reviews/CI), `mergeable: MERGEABLE`.
No file conflicts.

## Lesson
When a branch contains a mass directory rename and main adds files into the
pre-rename path, `git merge` will not auto-resolve the rename-vs-add. Always
inspect `apps/` for ghost directories after the merge and manually relocate.
