---
title: PR #90 statusline-polish — Senna nits follow-up review
date: 2026-04-26
agent: senna
pr: 90
verdict: APPROVE (advisory)
---

# Context

PR #90 (`statusline-polish`, Talon) addresses three nits I raised on PR #85:

1. Numeric clamp on `used_percentage` fields
2. Newline strip on MODEL `display_name`
3. `NO_COLOR=1` scoping fix in test case (b)

Diff: 14 add / 4 del in `claude-usage.sh`, 1 add / 1 del in `test-claude-usage.sh`.

# Findings

## Nit 1 — `_clamp_pct` (resolved with one residual)

The new helper uses a case-glob `*[!0-9.]*` to reject non-numeric input before
`printf '%.0f'`. Probed with 11 inputs:

- All headline garbage (`abc`, `5h`, `12abc`, `1e2`) → `--` ✓
- Negative inputs rejected (sign char) → `--` ✓
- Valid floats and ints → integer ✓

**Residual:** multi-dot strings like `1.2.3` pass the glob (since `.` is in the
allowed set), but `printf '%.0f'` partially writes `0` to stdout AND exits
non-zero — so `||` appends `--`, yielding `0--`. Same class of noise the clamp
was meant to suppress.

Fix options noted in review:
- Capture into a local first, only emit on full printf success
- Tighten regex to `*.*.*|*[!0-9.]*` to reject multi-dot

Filed as suggestion (low real-world likelihood from API).

## Nit 2 — newline strip (resolved cleanly)

`tr -d '\n\r'` on `display_name` output. Probed `"foo\nbar\rbaz"` → renders as
single-line `foobarbaz`. Correct tool for the job.

## Nit 3 — NO_COLOR scoping (case (b) fixed; case (c) regressed in same way)

Case (b) at line 51 now correctly has `NO_COLOR=1 bash "$SUBJECT"`. But case (c)
at line 57 still has the original misplacement (`NO_COLOR=1 printf ... | bash`).
The PR claimed to fix scoping but only fixed one of two instances.

Slip is silent: case (c) asserts on `5h 55%` substring, not ANSI codes, so the
test passes regardless. Filed as **important** cleanup (not blocking — fix in
follow-up).

**Deeper observation:** under the pipe-driven test setup, `[ -t 1 ]` is false →
`USE_COLOR=0` regardless of `NO_COLOR`. So case (b) was tautologically green
even with the misplaced env var. The scoping fix is correct in *intent* (makes
test exercise the documented contract) but doesn't change observable behavior
today. To actually verify `NO_COLOR` semantics, you'd need a `FORCE_COLOR=1`
flag in the script and assert ANSI absence under `NO_COLOR=1`. Worth a residual
note on the plan.

# Process notes

- Worktree `statusline-polish/` already existed, so `gh pr checkout` declined
  (fatal: already checked out). Read files directly from the worktree path.
- `scripts/reviewer-auth.sh --lane senna` → identity `strawberry-reviewers-2`
  preflight passed. Review submitted clean.
- Out-of-scope CI flag: `No AI attribution (Layer 3)` failing on PR #90 — noted
  in review tail. Not a code issue but a merge gate.

# Heuristic for future polish-PR reviews

When a PR claims to fix a class of bug across multiple sites, **search the
codebase for the same pattern** and verify ALL instances were fixed, not just
the ones explicitly named. Here: PR description mentioned "case (b)" by name,
and case (c) carrying the same bug was overlooked. Pattern-grep is cheap
insurance.
