# Stacked-PR base-branch check before merge

**Date:** 2026-04-19
**Session:** S57
**Tag:** #merge-discipline #gh-pr #stacked-prs

## What happened

Merged three portfolio-v0 PRs in sequence without checking `baseRefName` on each:
- `#29 V0.1` → base:main → merged cleanly to main ✓
- `#34 V0.4` → base:`feature/portfolio-v0-V0.3-firestore-schema` (NOT main) → `gh pr merge` pushed V0.4 content into V0.3's branch, not main.

The `gh pr merge` command merges into the PR's declared base, not the default branch. Squash-merging #34 collapsed V0.4 into V0.3's open branch, retroactively bundling two previously-approved PRs into one. `#33` had to be re-reviewed by both Senna and Lucian (Lucian needed independent merge-commit byte-verification per Rule 18).

## Lesson

Before merging any PR in a stacked chain:

```bash
gh pr view <n> --repo <owner/repo> --json baseRefName,mergeStateStatus,reviewDecision
```

If `baseRefName != main`, you have three options:
1. Merge the parent first, update-branch the child, then merge.
2. Retarget the child's base to `main` via `gh pr edit <n> --base main` (requires re-review if diff changes).
3. Accept the chain-collapse and plan for re-review of the bundled diff.

**Never** run `gh pr merge` on a stacked PR without this check — the harness doesn't catch it, GitHub accepts it silently, and you can't cleanly unwind it.

## Applies to

- Any Evelynn session handling multi-PR stacks (portfolio-v0, deployment-pipeline tasks, etc.).
- Yuumi's merge-sweep delegation prompts — add `baseRefName` to required JSON fields and a pre-merge branch check.
- Future reviewer/merger coordination: include the base branch in the merge-ready signal, not just "approved + green".

## Related

- `plans/approved/2026-04-17-branch-protection-enforcement.md` §3 — break-glass merge protocol assumes single-PR merges, stack cases need their own playbook.
- CLAUDE.md Rule 18 — the "author cannot approve own PR" check is per-PR; collapsed diffs need fresh approvals.
