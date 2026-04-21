# Sed greedy regex silently breaks hunk-header parsing on BSD awk path

**Session:** PR #15 (`fix: scope rule-4 path-existence check to staged-diff lines only`)
**Date:** 2026-04-21
**Finding severity:** Important

## The bug pattern

A hook parsing `git diff --cached --unified=0` hunk headers used:

```sh
new_part="$(printf '%s' "$hunk" | sed 's/.*+\([0-9,]*\).*/\1/')"
```

on hunk headers of form `@@ -old +new @@ trailing-context`. The trailing context is an arbitrary line from the source file (git's xfuncname pick). Greedy `.*` before the literal `+` means `+` matches the **last** `+` in the line, not the hunk-coordinate `+`. Whenever context contains `+<anything>`:

- `+<non-digit>` → `[0-9,]*` captures empty → `start=""` → `$((empty + i))` evaluates to `i` → wrong line numbers tracked in `staged[]`.
- `+<number>` → captures wrong number → rule 4 grandfathers real new lines silently.

## Why it wasn't caught

1. Primary awk path uses gawk 3-arg `match(str, re, arr)`; BSD awk (macOS /usr/bin/awk) bails with syntax error at compile time, so the fallback fires silently (stderr sunk to /dev/null).
2. No CI workflow runs the plan-structure hook tests — all 38 tests only ever ran on the author's macOS, always via the fallback.
3. The regression tests (R4-grand / R4-new / R4-mixed) used contexts like `"Existing good prose."` that don't contain `+`, so the bug never triggered.

## Reproducer

```sh
echo '@@ -12,0 +13 @@ context has +42 in trailer' | sed 's/.*+\([0-9,]*\).*/\1/'
# → 42   (expected: 13)
```

## Safer fix

Anchor the sed to the hunk-header grammar:

```sh
sed -E 's/^@@ -[^ ]+ \+([0-9]+(,[0-9]+)?) @@.*/\1/'
```

Tested against `@@ -12,0 +13 @@ prefix +nondigit`, `@@ -23,0 +24,2 @@`, `@@ -1 +1 @@`, etc.

## Review heuristic to remember

When reviewing shell parsers of git-produced data:
- Check whether the input grammar has trailing arbitrary content (diff hunk context, commit messages, ref names).
- `.*<delimiter>` greedy patterns are false-negative-prone whenever the delimiter CAN appear in that trailing content. Always anchor or use fixed-position extraction.
- If the primary code path is a gawk/BSD-awk extension, the fallback is NOT backup — on macOS it's the only path. Test the fallback as carefully as the primary.

## Related

- Prior RCE fix on this hook (`0f5dd15`, `cmd | getline` → `getline _ < full_path`) confirmed untouched in PR #15.
- Lucian's plan-fidelity review approved the PR; Senna's CHANGES_REQUESTED stood independently thanks to the `--lane senna` (`strawberry-reviewers-2`) lane-split that Rule 18/PR #45 incident motivated.

## Follow-up: re-review verdict (15ca3e2, 3f02851)

Talon's fix landed cleanly:
- Anchored sed verified against 8 hunk-header variants (trailing `+N`, single-line `+N`, pure-deletion `+N,0`, multi-digit, context with `a=b+c`, no-context, boundary cases). All correct.
- Dropped the gawk 3-arg match() primary entirely — removing dead code rather than fixing it is the right call.
- R4-trailer regression test (line 1352-1396) reproduces the exact failure mode: initial file ending in `+42` context, then staged append produces a hunk header with `+42` in the xfuncname position. Under greedy sed: staged[] would track line 42 only (beyond EOF), new bad-path line grandfathered, silent exit 0. Under anchored sed: correct start-line captured, rule-4 blocks.
- Tmpdir fix: `_empty_hooks="$dir/.empty-hooks"` nests inside the per-test repo tmpdir so one `rm -rf "$dir"` cleans both. Fresh run added 0 new `/tmp` directories.
- 39/39 tests pass. APPROVED at 2026-04-21T06:37:58Z.

Takeaway for future re-reviews: verifying the exact failure mode (not just "new test exists") by running the old buggy pattern against the new test fixture catches ghost-regression cases where a test passes for the wrong reason.
