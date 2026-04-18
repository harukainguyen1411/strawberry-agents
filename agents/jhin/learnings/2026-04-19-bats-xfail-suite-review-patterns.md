---
date: 2026-04-19
topic: bats xfail suite review — patterns and failure modes found in PR #25/#26
---

# Bats xfail suite review patterns (PR #25 + #26)

## Vacuous-pass hazard in xfail tests

A test that checks `status -ne 0` passes vacuously before the impl exists if the very `source` command fails (lib absent → non-zero exit). This makes the xfail suite look clean when it is not actually pinning the right failure mode. Fix: guard with `[ -f "${LIB}" ] || { echo "xfail: lib absent"; return 1; }` in tests that would otherwise vacuously pass. PR #25 applied this inconsistently — T8b was missing the guard while T4, T6c, T8d had it.

## bats `$stderr` is only populated with `run --separate-stderr`

Standard `run cmd` merges stdout+stderr into `$output`. The variable `$stderr` is only populated when using `run --separate-stderr` (bats-core 1.5+). Tests asserting `[[ "${stderr:-}" == *"pattern"* ]]` without `--separate-stderr` are no-ops — they silently pass even if the impl leaks to stderr. Always use `run --separate-stderr` for stderr assertions, or assert against the combined `$output`.

## Constant-equality assertions are tautological for TDD

A test that asserts a string constant equals a hardcoded value (`expect(BEE_INTRO_MESSAGE).toBe("...")`) fails the "not a tautology" criterion. It only catches intentional edits, not bugs. Real TDD smoke tests should exercise a function: assert on return shape, error path, or argument routing. String-constant pinning is a snapshot test, not a behavioural test.

## xfail suite must contain the impl commit on the same branch before merge

Rule 12 (xfail-first, impl-after, same branch). PR #25 had only the xfail commit; impl SHA `d52f1b9` did not exist. The branch must not merge with tests-only — the impl commit must be pushed onto the branch first.

## Static grep gates need tight exclusion patterns

`check-no-bare-deploy.sh` excluded all of `__tests__/` from the gate scan. Tighter exclusion should target only `__tests__/fixtures/` so future test helpers in `__tests__/` are still scanned. Overly broad exclusion creates blind spots.

## repo-root detection from `command -v decrypt.sh` is fragile

Resolving repo root via `dirname "$(command -v decrypt.sh)"` breaks when the tool is installed to a system PATH location outside the repo. Prefer `BASH_SOURCE[0]`-relative resolution: `REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"`.

## `package.json` deploy scripts bypass the gate

A bare `firebase deploy --only functions` in `package.json` `scripts.deploy` does not specify `--project`. The G2 grep gate in `_lib.sh` only scans `scripts/deploy/**` — it never sees `package.json`. This is a footgun: `npm run deploy` uses whatever Firebase project is active. Either hard-code `--project` or delete the script in favour of using the surface scripts exclusively.
