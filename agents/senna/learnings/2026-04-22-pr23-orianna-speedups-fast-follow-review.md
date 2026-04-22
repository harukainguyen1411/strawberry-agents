# 2026-04-22 — PR #23 Orianna speedups fast-follow review

## Context
Karma's fast-follow PR addressing my own PR #19 findings F1–F6 on the Orianna gate scripts. Branch `feat/orianna-speedups-fast-follow`. Two commits: xfail `e7556d2` (T1) + impl `0133fcb` (F1–F6). Plan: `plans/in-progress/personal/2026-04-22-orianna-speedups-pr19-fast-follow.md`.

## Verdict
Advisory LGTM (COMMENTED). All six findings from PR #19 land correctly; four new observations, none merge-blocking.

## Top new findings

1. **Important — T2 snapshot/restore is single-path.** `orianna-sign.sh` restores on `block_count>0 || claude_exit==1`, but NOT on `claude_exit==2`, "no report found", or interrupt paths. Rule 1 (no uncommitted work) is still partially violated. Fix needs a `trap` right after the `cp` snapshot. Fast-follow candidate, not a blocker because the common block-findings path is covered.

2. **Important — test exercises only the fixed path.** xfail test stubs claude to return exit 1 with block_findings=1 — the exact path the fix covers. Does not cover exit 2 / missing report / SIGINT. Green test signal slightly overstates coverage. Also minor: a second `trap` statement overwrites the first one (line 32 vs line 96) — first is dead code.

3. **Suggestion — inner mktemp in body-hash-guard still `/tmp/`-prefixed.** F4 made the outer failure-tempfile honor `$TMPDIR`, but `STAGED_TMP="$(mktemp /tmp/body-hash-guard-XXXXXX.md)"` in the loop still hardcodes `/tmp/`. Rule 10 portability nit. Pre-existing, not introduced by #23.

4. **Nit — `_FAIL_TMP` has no `trap` cleanup.** Both terminal branches clean up; any injection of `set -e` or early abort would leak. Cheap belt-and-suspenders.

## Clean
F1 TTY-guard, F3 grep-c-||true, F4 mktemp + `-s` check adjustment (correct for pre-created file), F5 regex widening, F6 comment fix. All implemented as my PR #19 review recommended.

## Reusable technique
When reviewing a "fix for X" PR, check that the fix handles ALL paths where X can occur, not just the one the test exercises. Here: snapshot/restore covers `exit 1` but the script has two other exit paths that re-trigger the same Rule 1 violation. A passing xfail test can mask partial fix coverage — always diff the fix against the set of failure branches, not just the failure the xfail reproduces.

## Lane hygiene
Auth check passed cleanly as `strawberry-reviewers-2`. COMMENTED review posted at PR #23.

## Review URL
https://github.com/harukainguyen1411/strawberry-agents/pull/23
