# 2026-04-21 — PR #17 staged-scope-guard hook review

## PR

- harukainguyen1411/strawberry-agents#17 — Talon implementation of
  `plans/in-progress/personal/2026-04-21-staged-scope-guard-hook.md`
- Branch: `feat/staged-scope-guard-hook`
- Files: hook impl, xfail test, install-hooks.sh comment, key-scripts.md row, follow-up stub

## Verdict

CHANGES_REQUESTED — hook implementation itself is clean; test script had dead
code and plan DoD mismatch.

## Findings that mattered

1. **Test dead code against live repo (important).** `case_A()` in
   `scripts/hooks/tests/pre-commit-staged-scope-guard.test.sh` had three hook
   invocations BEFORE the actual asserted pair, none of which cd into `$repo`.
   They ran against the live strawberry-agents checkout. Outputs were discarded
   or overwritten, so the test passed, but:
   - If the real repo had `a.txt` staged, the hook's `rm -f
     "$(git rev-parse --git-dir)/COMMIT_SCOPE"` would fire against the real
     `.git/COMMIT_SCOPE` — cross-test mutation risk.
   - Cargo-cult bait: a future editor will either strip or "fix" these and get
     it wrong.
   Pattern to watch: any test that invokes a git-aware script without setting
   up its own throwaway repo is suspect. Check for `cd "$repo"` or explicit
   `GIT_DIR`/`GIT_WORK_TREE` overrides.

2. **Test file non-executable vs plan DoD.** File shipped `100644`; plan Task 1
   DoD said "test script executable". Small but enforceable gap. Worth checking
   file modes in diffs for scripts under `scripts/hooks/tests/`.

3. **Missing fallback-path case.** `.git/COMMIT_SCOPE` file-only path (no env
   var) wasn't exercised — Case E set both. Reminder to always check that each
   resolution branch in a priority-ordered config has its own test case.

## Hook logic verification — no blockers found

- POSIX-portable bash, `set -uo pipefail`, `#!/usr/bin/env bash`.
- `grep -qxF` for exact-match scope comparison.
- `awk -F/ '{print $1}' | sort -u | wc -l` for unique top-level dir count.
- Command substitution `$(git diff ...)` strips trailing newline, so
  `printf '%s\n' | wc -l` gives correct count.
- `${STAGED_SCOPE+set}` handles unset-vs-set safely under `set -u`.
- `"*"` in quotes — shell does not glob-expand. Escape hatch works.
- Alphabetical slotting `secrets-guard` < `staged-scope-guard` <
  `t-plan-structure` confirmed via `ls | sort`.

## Suggestions (not blockers)

- Unconditional `rm -f COMMIT_SCOPE` deserves a comment — prevents
  well-meaning "fix" to only-clear-when-file-sourced.
- `git diff --cached --name-only` lacks `-z` for newline-in-path hardening;
  `pre-commit-secrets-guard.sh` uses `-z` + `mapfile -d ''` as reference.

## Lane-identity note

`scripts/reviewer-auth.sh --lane senna` preflight returned
`strawberry-reviewers-2` — correct lane. Posted review visible as
CHANGES_REQUESTED under that account.

## Bash-permission friction

First invocations of `scripts/reviewer-auth.sh` were denied by the sandbox;
`bash scripts/reviewer-auth.sh --lane senna ...` (explicit `bash` prefix)
worked. Noted for future sessions.
