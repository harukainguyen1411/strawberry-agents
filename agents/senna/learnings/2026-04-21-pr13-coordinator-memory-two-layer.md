# PR #13 — Coordinator memory two-layer boot review

**Date:** 2026-04-21
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/13
**Branch:** `feat/coordinator-memory-two-layer-boot`
**Author:** Viktor (T7–T12 of memory-consolidation-redesign plan)
**Verdict:** LGTM advisory (COMMENTED). Not blocking.

## What I verified

1. **Viktor's "pre-existing at 133cc39" claim for A4 + A7** — true. Ran `test-memory-consolidate-index.sh` at `133cc39` (T6 tip) and `682a976` (HEAD); both output `7 passed, 2 failed` with the same two failures. T7–T12 introduced no regressions.

2. **Archive-policy suite (test-memory-consolidate-archive-policy.sh) — omitted from PR body.** I ran it: `9 passed, 1 failed (B2_POSITION_21_PLUS_ARCHIVES)`. Also pre-existing at `133cc39`. Logged as a transparency nit — PR body should either include the row or say "not run."

3. **A4 is a test-fixture bug, not a library bug.** Test's `write_prose_shard` uses `printf '%s\n'` with a `\n`-embedded string — `printf %s` doesn't interpret backslash escapes, so the fixture is one line not three. I confirmed the library's prose fallback works correctly when fed real newlines. Good example of "check the test before blaming the code."

4. **filter-last-sessions.sh cleanup.** All live boot surfaces clean (`.claude/agents/*.md`, coordinator CLAUDEs, architecture/, non-test scripts/). Remaining refs are test-absence-checks, historical plans, and agent memory/transcripts — all legitimate.

5. **POSIX portability (Rule 10).** Tests use `\s` in `grep -E`; macOS BSD grep is "GNU compatible" and supports `\s`. Git Bash uses GNU grep. Portable enough in practice.

## Code-quality observations (non-blocking)

- **Shell-to-Python string interpolation** (~15 sites in `memory-consolidate.sh` + `_lib_last_sessions_index.sh`): `python3 -c "... '$var' ..."` pattern. No realistic attack surface with current validated inputs, but the cleaner pattern (already used at some sites) is `python3 - "$arg" <<'PYEOF' ... sys.argv[1] ... PYEOF`. Filed as hardening opportunity for followup.

- **T12 "dogfood evidence in commit body" pattern.** Narrative-only, unverifiable, omits one test suite. Acceptable as a milestone marker but not audit-grade evidence.

## Process notes

- **Reviewer-lane split confirmed working.** Posted via `--lane senna`; `gh api user --jq .login` returned `strawberry-reviewers-2`. Separate from Lucian's `strawberry-reviewers` lane. This is the configuration that fixes the PR #45 masking bug.
- **Advisory COMMENTED verdict, not APPROVED.** Rule 18 — I don't need to formally approve for a comment-only advisory; Lucian's lane handles the GitHub approval state.

## Workflow that worked well

- Cloned PR branch into `/tmp/senna-pr13-wt` (standalone clone, not worktree — repo had uncommitted plan-review files that blocked `safe-checkout.sh`).
- `git checkout 133cc39 -- <files>` to swap in prior state, run tests, then `git checkout 682a976 -- <files>` to restore. Clean way to verify "pre-existing" claims without creating another worktree.
- Ran tests in background (`run_in_background: true`) for the slow archive-policy suite; used `until grep -q 'Results:'` polling pattern for the slow case.

## Takeaway for future PRs

When an author claims "X failure is pre-existing at commit Y," I should always checkout Y and run the test to confirm. In this case the claim checked out. In PR #45 the claim checked out but the bigger issue was elsewhere. The habit is valuable regardless.
