# PR #64 — coordinator-decision-feedback rollup math bug

Date: 2026-04-25
Verdict: REQUEST CHANGES
PR: https://github.com/harukainguyen1411/strawberry-agents/pull/64

## Headline finding

The match-rate formula in `rollup_preferences_counts` (`scripts/_lib_decision_capture.sh:812-815`) is wrong. It computes `count(duong_pick == 'a') / total_explicit` instead of the plan-specified `sum(match) / total_explicit`. The variable `match_count` is correctly maintained at line 797 but never read. The fixtures have `coordinator_pick == 'a'` for almost every match, so the buggy formula produces the same number as the correct one — except for `svd-4` (b/b/true). Test `preferences.expected.md` locks in 67% (the wrong number); the correct value for the same fixture is 83%.

## Generalizable lessons

1. **When test fixtures and impl share an authorship event, the test does not validate semantics — it locks in whatever the implementer chose.** Always re-derive the expected value from the plan/spec, not from running the impl. PR #64's TT2-rollup test asserts `Match rate: 67%`. Reading it cold, the number plausibly matches `4/6 ≈ 67%` or `5/6 ≈ 83%` — only by computing both and comparing to the plan's `match_rate = sum(match) / count` did the bug surface.

2. **Search for "dead variable" / "computed but never read" patterns in stats aggregators.** `match_count` was the giveaway — a counter declared, incremented, and orphaned alongside another counter (`s['counts']['a']`) used in its place. Grepping for `match_count` (4 hits, only 3 of which are write-side) made the dead-variable obvious.

3. **Fixture monoculture hides math errors.** Every match-true fixture had `coordinator_pick: a`. The one exception (svd-4: b/b) coincidentally produced the same delta. A diverse fixture set (b/b, c/c, b/a, c/b matches and mismatches) would have made the bug self-evident at test-design time. Coverage gap to flag in future reviews of any aggregation/stats code: do the test fixtures span the input space, or do they all share one dimension?

4. **Agent prompt vs CLI contract drift is a real failure mode for skill-wrapped scripts.** Evelynn/Sona's "piping the file contents on stdin" instruction contradicts `capture-decision.sh --file <path>`. The SKILL.md was correct; the agent prompts (which the model sees on every invocation) were wrong. Whenever a SKILL wraps a script, the protocol section in the agent def MUST quote the SKILL.md verbatim or the production caller will use the wrong invocation.

5. **`DECISION_TEST_MODE` documented-but-unused → smell.** The lib documents an env-var gate that doesn't exist in code. Combined with bind-contract tripwires that fire before any rename-hook code path can execute, the entire `_decision_field_*` indirection layer is unreachable. Either the gate was removed without removing the dead code, or the bind-contract tripwire was added later without recognizing the redundancy. Either way, code paths in the validator that are physically unreachable in production are a maintenance trap.

## Process notes

- Worktree at `/private/tmp/strawberry-coordinator-decision-feedback` had been pre-created — `scripts/safe-checkout.sh` errored with "untracked files," which was misleading. Resolved by reading via the worktree path directly.
- xfail harness (`scripts/test-*.sh`) always `exit 0` regardless of outcome. Once impl is in, the harness stops being a regression gate. Worth raising with the test-impl pair-mate (Rakan) for future test patterns.
- Plan §6 binding `match_rate = sum(match) / count` was the load-bearing source-of-truth that confirmed the bug. Reading the plan's Bind-points table BEFORE diffing the code is the right order — saves time chasing minor things while missing the central correctness defect.

## What I caught vs missed

Caught: B1 match-rate, I1 stdin-vs-file contract, I2 path-traversal hole in non-date-prefixed validation, I3 dead test-mode gate, I4 lock skip in --decisions-only.

Missed (initial pass): I almost let the test-passing claim ("72/72 passing") shadow my read of the formula. Caught it only when grepping `match_count` for unrelated reasons and noticed the ratio of writes to reads was 3:0.
