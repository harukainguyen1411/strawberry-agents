# PR #71 re-review — qa-pipeline T6b/T7b APPROVED

**Date:** 2026-04-26
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/71
**Branch:** `qa-pipeline-t6-t7-xfail` @ `0abfa0e6`
**Verdict:** APPROVED (was CHANGES_REQUESTED in round 1)

## What I learned

### Verifying fence-state in awk-based markdown linters

For a heading detector that must ignore fenced code blocks, the awk pattern is:

```awk
/^```/ { fence = !fence; next }
!fence && /^## QA Plan[[:space:]]*$/ { in_section=1; next }
!fence && in_section && /^## / { exit }
in_section { print }
```

Two subtle correctness properties:
1. The fence-toggle rule has `next`, so the fence line itself never reaches the
   in-section print rule.
2. The section-end rule (`^## `) is gated by `!fence`, which is what allows a real
   `## QA Plan` section to *contain* a fenced `## QA Plan` example without prematurely
   exiting. Verified locally — the embedded fenced heading does not break out of
   the real section.

Caveat: this only handles backtick fences. Tilde fences (`~~~`) silently shadow
the detector. For this repo it's fine (uniform backtick convention), but worth
noting if anyone reuses the helper.

### here-doc fix for printf|while subshell + PID-tempfile combo

Round 1 had:
```sh
printf '%s\n' "$_HEADINGS" > "/tmp/foo-$$"
while IFS= read -r h; do ... done < "/tmp/foo-$$"
```
Two bugs in one: (a) `printf | while` runs the loop in a subshell so failure flag
mutations are lost, AND (b) `/tmp/foo-$$` collides on PID reuse across concurrent
invocations.

The fix collapses both into a single here-doc, which (a) keeps the while in the
current shell so `_cqpb_fail=1` propagates and (b) eliminates the tempfile entirely:

```sh
while IFS= read -r _heading; do ... done <<EOF
$_QA_PLAN_REQUIRED_SUBHEADINGS
EOF
```

### Whitespace + CRLF normalisation pattern

`sed 's/[[:space:]]*$//'` on both the haystack section AND the needle heading
before `grep -qxF` cleanly handles trailing-space contamination and Windows CRLF.
Using `grep -xF` (fixed-string exact-line) instead of regex avoids the metachar
trap with parenthesised headings like `### Failure modes (what could break)`.

## Process notes

- All 6 round-1 findings closed cleanly. No new findings introduced by the fix.
- Reviewer added 5 regression tests (T6a-8/-9/-10, T7a-8/-9) — exactly the right
  pattern for a fix-train PR: ratchet new test coverage so the same bugs can't
  re-emerge.
- 22/22 bats green, verified locally on a fresh clone.
- Identity: `strawberry-reviewers-2` (Senna lane) confirmed via preflight.

## Reusable heuristic

When a reviewer comes back with a fix-train commit and claims "all green":

1. Clone the branch fresh, run the test suite locally — don't trust the PR body alone.
2. Read the diff with the prior findings open in another window. Check off each one
   against the actual code, not the commit message.
3. For each fix, construct a minimal reproducer that *would* have triggered the
   original bug, run it against the fixed code, and verify it now passes (or fails
   with the right BLOCK message).
4. Boundary-check numeric thresholds (e.g. 9 vs 10 chars).
5. Look for one new edge case the fixer may not have considered (here: tilde fences).
   Flag as suggestion if non-blocking.
