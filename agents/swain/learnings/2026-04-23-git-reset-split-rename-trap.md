# Git reset split-rename trap — accidentally committing file deletions

**Date:** 2026-04-23
**Context:** Amending a plan file while concurrent agents had in-flight work in the tree.

## The trap

When another agent is mid-way through a `git mv plans/approved/X.md plans/implemented/X.md`, the working tree shows:

```
M  plans/approved/personal/X.md         (staged — "deleted half of rename")
?? plans/implemented/personal/X.md      (untracked — "added half")
```

(Status can also appear as `RM` or `MM` depending on how the other agent staged.)

If I call `git reset HEAD -- plans/approved/personal/X.md` to unstage only the "deletion" side, git happily unstages that. But if the rename was staged as a pair (add + delete), the destination-half may also show in the index; resetting only one side leaves the other half in the index.

In my 2026-04-23 session:
1. I reset the destination half (`plans/implemented/.../X.md`) while the source-delete half remained staged.
2. My commit `b4a0edf` (ADR amendment, intended to touch ONE file) recorded a spurious file deletion of `plans/approved/personal/X.md`.
3. `git show b4a0edf --stat` showed **2 files changed**, not 1 — the tell I missed before pushing.

## The fix going forward

1. **Always verify `git diff --cached --name-only --diff-filter=ACMR` matches expectation immediately before commit.** If the list has more than the file I intend to touch, stop.
2. **Reset BOTH halves of a rename.** If status shows `M  approved/X.md` and `?? implemented/X.md` (or any pair pointing at the same basename in different lifecycle dirs), reset **both** paths in one `git reset HEAD --` invocation before committing. The untracked-file half doesn't need resetting, but any `M`/`A`/`D` half of the pair must be cleared.
3. **Check `git show HEAD --stat` immediately after commit.** If file count != expected, revert before pushing.

## Recovery is painful when the deleted file fails the current-day linter

Attempting to restore the accidentally-deleted file via a follow-up commit was blocked by `pre-commit-zz-plan-structure.sh` because the file's content was approved under a looser linter. I couldn't edit the other agent's plan to pass the current linter, and `--no-verify` is forbidden (Rule 14). Result: I had to leave the file as untracked in the working tree and flag in my return report for the concurrent agent / Duong to finalize.

**Moral:** Prevention is much cheaper than recovery. Check the diff before `git commit`, not after `git push`.

## Related context

- Rule 1 (Never leave work uncommitted) — this trap turns "commit before another agent steals work" into "commit and accidentally overwrite another agent's work."
- Concurrent subagent dispatch (multiple Orianna/Ekko/Swain sessions in parallel) makes the working tree a shared surface. Treat `git status` as adversarial: assume every file you didn't touch is someone else's in-flight work.
