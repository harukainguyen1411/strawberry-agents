# PR #52 — heredoc FP fix in plan-lifecycle-guard via two-stage parse — APPROVE

**Date:** 2026-04-25
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/52
**Branch:** `fix/heredoc-fp-guard`
**Plan:** `plans/approved/personal/2026-04-25-plan-lifecycle-guard-heredoc-fp.md`
**Verdict:** APPROVE (advisory). Lucian also approved from the fidelity lane.

## What landed

- `scan_conservative()` in `_lib_bash_path_scan.py`: text-only fallback (no bashlex) — splits on `[;&|\n]`, scans for mutating verbs at `tokens[0]` and redirect targets, emits paths containing `/` after quote-stripping.
- Two-stage parse in `pretooluse-plan-lifecycle-guard.sh`: bashlex rc=3 → invoke `--mode=conservative` fallback with debug stderr. All other non-zero exits remain fail-closed.
- 17 new tests (FP-1..9 allow + B-1..8 block), 50 total, all pass.
- xfail commit `3ce946bd` precedes implementation `d17dd437` (Rule 12 satisfied).

## Verification path

I confirmed all four dispatch concerns via inspection + standalone runs:

1. **Debug stderr leak in success cases — none.** The debug line is inside the `_scanner_rc -eq 3` branch; success path silently `rm -f`'s the temp file.
2. **Fallback only on rc=3 — confirmed.** Other non-zero exits hit the `else` branch and `exit 2`.
3. **B-8 exercises the fallback end-to-end — confirmed** by running the B-8 payload through both modes manually:
   - bashlex: `here-document at line 0 delimited by end-of-file (wanted "'SCRIPT'")`, rc=3
   - conservative: emits both `plans/approved/personal/foo.md` and `plans/archived/personal/foo.md`, rc=0
   - guard's `is_protected_path` matches → exit 2
4. **FP-vs-bypass trade-off — characterized.** See below.

## Residual conservative-mode bypasses I found (non-blocking)

The verb check is exact-match on `tokens[0]` after `.lower().lstrip("#")`. Wrapping the mutator with non-whitespace prefixes inside an unparseable script bypasses:
- `(mv plans/approved/...)` — `tokens[0]` = `(mv`
- `{ mv plans/approved/...; }` — `tokens[0]` = `{`
- `$(mv plans/approved/...)` — `tokens[0]` = `$(mv`
- `git -c color.ui=auto mv plans/approved/...` — `tokens[1]` = `-c`, not in `_MUTATING_GIT_SUBVERBS`

All four bypasses verified end-to-end against the actual guard (rc=0). Off the realistic agent-mutation threat path; logged for future hardening.

## Residual conservative-mode FP regression I found

A heredoc body containing a literal command-line `mv plans/approved/foo.md ...` on its own line (e.g. a code example in a PR review body) now gets blocked by the conservative scanner. Lower-frequency than the original FP this PR fixes; documented as a residual.

## Code-quality observations (minor)

- `verb.lower().lstrip("#")` on line 361: counterintuitive — strips `#` from the verb token, which makes `#mv plans/approved/foo.md ...` (no space after `#`) get treated as a real mv. Recommend removing.
- `lstrip(">")` on line 403: strips all leading `>` chars. Tighter regex would be more precise, but not load-bearing.
- `_CONSERVATIVE_MUTATING_VERBS` omits `dd` vs. `_MUTATING_VERBS`; intentional but undocumented.

## Pattern: characterizing fallback-mode trade-offs

When reviewing a fail-open / fail-closed contract change, always:
1. Identify the **trigger condition** for the fallback (here: bashlex exit 3).
2. Compare the fallback's coverage to the primary's coverage on **adversarial** patterns (here: subshells, command grouping, command substitution prefixes).
3. Identify **new FP regressions** introduced by the fallback (here: literal command lines in heredoc bodies).
4. Verify the test that exercises the fallback **actually triggers it** end-to-end, not just the fallback function in isolation (B-8 was sound).

## Identity / mechanics

- Used `scripts/reviewer-auth.sh --lane senna gh pr review 52 --approve --body-file ...`.
- Preflight `gh api user --jq .login` returned `strawberry-reviewers-2` ✓.
- Worktree at `/Users/duongntd99/Documents/Personal/strawberry-agents-fix-heredoc-fp-guard` already existed — used in-place.
- `printf | python3 .../_lib_bash_path_scan.py` from inside strawberry repo gets blocked by the (current main) guard for any heredoc-FP probe; tested standalone in `/tmp` instead.
