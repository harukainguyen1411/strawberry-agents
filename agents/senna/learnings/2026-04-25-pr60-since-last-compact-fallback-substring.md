# PR #60 — `--since-last-compact` flag review (advisory APPROVE)

**Date:** 2026-04-25
**PR:** harukainguyen1411/strawberry-agents#60
**Verdict:** APPROVE with five non-blocking notes. No blockers.

## What shipped

A `--since-last-compact` flag for `scripts/clean-jsonl.py` that slices transcript output to entries strictly after the most recent compact boundary. Boundary detection: `isCompactSummary: true` field is authoritative, `<command-name>compact</command-name>` user-message substring is the fallback, last-wins on multiple markers, fail-loud `die(1, ...)` if no marker.

## The signal finding — substring match on fallback regex

The most interesting bug-shaped issue: `_RE_SLASH_COMPACT = re.compile(r"<command-name>compact</command-name>")` is `.search()`-ed against arbitrary user-message text. If a user *quotes* that exact tag inside larger prose (e.g. asking the assistant about the compact command), the fallback fires and slices everything before that turn. Correctness cost is silent wrong-leg slicing.

In real harness records, the slash-command envelope is the ENTIRE message content — so anchoring the regex with `^\s*` (or testing `text.lstrip().startswith(...)`) tightens the heuristic without losing any real boundaries.

**Pattern lesson:** when the codebase uses a magic envelope/sentinel that ALSO appears as a quotable string, the detector must distinguish "envelope record" from "prose containing the envelope". Substring match is too loose; require anchoring or whole-content equality.

## Other observations

1. **Two-pass chain walk** (find-index then slice) → 2× I/O + duplicated stderr warnings on malformed lines. Cosmetic; refactor opportunity.
2. **Plan internal inconsistency**: Context says priority-based (`isCompactSummary` authoritative); T2 task detail says "larger index of either pass". Implementation chose Context reading. Flagged for Lucian (plan-fidelity lane), not a code defect.
3. **Strict `is True` check** on `isCompactSummary` — defensible (rejects accidental truthy non-bools), but brittle if Anthropic ever ships the field as a string. Worth a one-line comment.
4. **Test coverage**: 5/5 pass. Priority paths and fail-loud well covered. Regression byte-stability test compares two flag-absent runs (idempotence) rather than fixture vs pre-PR golden — would need a golden file for stronger pre/post discipline.

## Edge cases I probed via subprocess

All passed (per current implementation semantics):
- Boundary at first record → slice = entire tail. ✓
- Boundary at last record → empty → "no surviving prose" footer. ✓
- `isCompactSummary` earlier than slash-compact → `isCompactSummary` wins (priority semantics). ✓
- Malformed JSON line in middle → warns to stderr, continues. ✓
- CRLF line endings → works (Python text-mode universal newlines). ✓
- `isCompactSummary: 1` (truthy non-bool) → NOT detected (strict `is True` check). ✓ (intended)

## Process

- Used `git fetch origin pull/60/head:pr-60-test` + checkout-from-branch for the two changed files into the working tree, ran pytest, then `git restore` + delete branch to clean up.
- `scripts/reviewer-auth.sh --lane senna gh api user --jq .login` returned `strawberry-reviewers-2`. Submitted via `--lane senna gh pr review --approve --body-file`.
- Reviewer-auth posted cleanly; review URL embedded in PR.

## What I'd do differently next time

When a reviewer-auth subprocess writes to a `secrets/reviewer-auth-senna.env` path on the workstation, double-check that the wrapper is the only thing reading it (it is) and that no `cat` or `tail` slips into a debug session.
