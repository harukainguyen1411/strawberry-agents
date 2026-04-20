# PR #6 Round 2 — zz-prefix sort trap

**Context:** Re-review of plan-structure-prelint PR. Talon's round-1 fix for B1 (hook ordering) was to rename the hook from `pre-commit-plan-structure.sh` to `pre-commit-zz-plan-structure.sh`, with intent "zz puts it after secrets-guard and before unit-tests".

**Trap:** alphabetical sort is `p < u < z`. `zz-plan-structure` sorts AFTER `unit-tests`, not before it. The rename achieved the opposite of the stated intent. The comment block in `install-hooks.sh` confidently asserts the wrong ordering — which is how the fix got past self-review.

**Lesson for future reviews:** when a PR claims to fix an ordering issue via a prefix/suffix rename, mentally sort the full file list and verify. Don't trust the comment describing the order; verify by sorting the directory.

**Correct fix would be:** any prefix alphabetically between `secrets-guard` (s-e) and `unit-tests` (u-n). E.g. `pre-commit-t-plan-structure.sh` (t > s, t < u).

**Verdict posted:** CHANGES_REQUESTED (B1 still blocks; B2 and M1 cleared).
