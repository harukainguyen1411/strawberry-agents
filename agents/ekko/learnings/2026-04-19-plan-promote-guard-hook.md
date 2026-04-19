# 2026-04-19 — plan-promote-guard pre-commit hook

## What was done
Wrote and wired `scripts/hooks/pre-commit-plan-promote-guard.sh` to block silent
Orianna fact-check bypasses. The hook detects when a staged diff moves a plan
out of `plans/proposed/` (handling both git rename `R` status and separate `D`+`A` entries),
then requires either a matching fact-check report or an explicit `Orianna-Bypass:` trailer.

## Key learnings
- `git diff --cached --name-status` outputs renames as `R100<TAB>src<TAB>dst` — a
  single line with two paths, not two separate D/A lines. Must handle both forms.
- When invoking a hook with only `GIT_DIR` set (not from within the worktree),
  `git rev-parse --show-toplevel` fails. Must also set `GIT_WORK_TREE` in test harness.
- `COMMIT_EDITMSG` is populated before pre-commit fires when `--message` is used.
  Writing to it in tests correctly simulates the trailer check.
- install-hooks.sh dispatcher pattern means new hooks just need to follow the
  `pre-commit-<name>.sh` naming convention — no installer edits needed.
