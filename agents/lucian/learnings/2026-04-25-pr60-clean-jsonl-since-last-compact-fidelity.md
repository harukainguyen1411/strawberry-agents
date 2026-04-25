# PR #60 — `--since-last-compact` flag fidelity review

**Date:** 2026-04-25
**Verdict:** APPROVE (strawberry-reviewers)
**Plan:** `plans/approved/personal/2026-04-25-clean-jsonl-since-last-compact.md` (Karma quick-lane)
**Commits reviewed:** `f7ec9225` (T1 xfail), `972be9a6` (T2 impl + T3 docs)

## Notable

1. **Plan-internal ambiguity Talon resolved correctly.** Plan §Context (L17) said `isCompactSummary` is *authoritative* with slash-command as fallback. T2 detail step (2) (L24) said "return the larger index of either pass" — which would interleave the two markers by position. Talon implemented the Context-level invariant (priority-ordered), and the test matrix (case d explicitly tests fallback only when `isCompactSummary` is wholly absent) backs that reading. Lesson: when a plan's Tasks-level wording contradicts its Context-level invariant, the Context wins — flag the tasks-level wording as drift but don't block.

2. **xfail strict=True for 4 cases, strict=False for case (e).** Correct nuance: case (e) is a flag-absent regression test — it never fails pre-impl because the flag-absent code path is unchanged. Marking it `strict=True` would make T1 commit immediately fail CI; `strict=False` correctly allows xpass. Worth remembering for future xfail-first reviews.

3. **Plan-vs-skill numbering drift.** Plan T3 said "Step 5" but the actual Lissandra skill numbers it Step 6. Talon edited the right step (matched by content "transcript excerpt") despite the number mismatch. Non-blocking.

4. **Test-vs-plan byte-equal interpretation.** Plan §Test plan called case (e) "byte-equal to baseline run"; T2 DoD specified a manual diff against a pre-change run. The test compares two flag-absent runs against each other (determinism + entries-survive invariant), not pre-vs-post change. The manual-diff DoD is satisfied out-of-band. Drift note, not block.

## Invariants confirmed

- Rule 5: `chore:` correct (no `apps/**`).
- Rule 12: T1 xfail (5 markers, 4 strict + 1 non-strict) precedes T2 impl (all 5 markers removed) on the same branch.
- Rule 21: clean.
- Stdlib only, single-file impl scope, POSIX-portable.
- 5/5 tests passing; each non-trivial (each test asserts both presence of post-marker entries AND absence of pre-marker entries, or the exact `die(1, ...)` message).

## Reviewer-auth path

Personal concern — `scripts/reviewer-auth.sh` (default lane), no `--lane` flag. Preflight `gh api user --jq .login` returned `strawberry-reviewers` ✓.
