# Pre-commit `plan-structure` hook auto-fix sweeps worktree-wide, can bundle other agents' edits

**Date:** 2026-04-27
**Context:** Re-authoring ADR amendment 3 to `plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md` after a history-rewrite recovery (see sibling learning `2026-04-27-filter-repo-stale-clone.md`).

## What happened

I ran `git add plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md && git commit -m "<my-amendment-3-message>"`. Only the ADR was in my staging area, verified by `git diff --cached --name-only`.

The commit appeared to fail with `Exit code 1` and a `[pre-commit-zz-plan-structure]` complaint about `plans/proposed/work/2026-04-27-sse-emit-status-building-on-builds.md` (an unrelated SSE plan owned by a different agent's session, missing `priority:` and `last_reviewed:` frontmatter).

But the commit actually succeeded — bundled together with an auto-fix to that SSE plan's frontmatter, under the commit subject `chore(sse-emit): add qa_plan/priority/last_reviewed frontmatter for Orianna gate` (NOT my intended message). My amendment-3 ADR diff and §Amendment log entry landed correctly inside that commit; only the commit-subject lineage was wrong.

## What the hook is doing

The `plan-structure` pre-commit hook scans ALL plan files in the worktree (not just staged ones) and validates frontmatter. When it finds a violation, it auto-fixes the file AND amends the staging area to include the fix, AND apparently rewrites the commit subject to describe the auto-fix rather than the user's original intent.

In a multi-agent worktree (this repo IS a multi-agent worktree by design), this means: **agent A's `git commit` for their own clean file can sweep up unrelated in-progress edits from agent B's session, attributing both changes to agent A's commit under a subject that describes agent B's fix.**

## Generalizable lesson

**Pre-commit hooks that auto-fix files outside the staging area are dangerous in shared worktrees.** They violate the principle of least surprise (committer expects to commit only what they staged) and break commit-blame attribution (whoever committed gets credited with whatever auto-fix landed). In a single-agent worktree it's a feature; in a multi-agent worktree it's a footgun.

## What to do about it

1. **As an agent committing in a shared worktree**, run `git status -s | head` immediately before `git commit` and look for unrelated `M` or `??` files in `plans/`. If you see them, either:
   - Wait for the other agent's session to commit/finish, OR
   - Use `git stash --keep-index` to set aside everything outside your staging area before committing, then `git stash pop` after.
2. **Verify your commit subject post-commit** with `git log --oneline -1` — if it doesn't match the message you wrote, you got swept. Decide whether the muddle is worth a force-push fix (almost always: no — git blame on the file body still works correctly).
3. **For the hook itself** (separate plan needed): scope the auto-fix to staged files only, OR refuse to commit when unstaged plan-structure violations exist (forcing the committer to deal with them explicitly), rather than silently auto-fixing and amending.

## Workaround for this session

I left the muddle in place (`af788355` carries my amendment-3 prose under a misleading subject). Reverting would have required force-pushing on top of a fresh history-rewrite recovery — wrong cost/benefit for a cosmetic blame-attribution issue. ADR content is correct; that's what matters for the project.

## Related session

- Amendment 3 lineage muddle observed during the 2026-04-27 ADR re-author session. Final SHAs: `919a7149` (amendment 2, clean), `af788355` (amendment 3, bundled with SSE-plan frontmatter fix), `e07bf8ad` (amendment 4, clean).
- Team-lead has filed a follow-up plan to tighten the hook's scope.
