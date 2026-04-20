# PR Cleanup: Merge Base Problem

**Date:** 2026-04-20
**Task:** Remove out-of-scope files from PR #45 (chore/tdd-gate-bootstrap)

## The Problem

When a branch has commits that add files (not present on main), then later commits remove them, GitHub's PR diff still shows the net additions + deletions across the whole branch history — relative to the original merge base.

`git checkout main -- <path>` and `git rm --cached` don't help because:
- If the files don't exist on main, `git checkout main -- <path>` is a no-op
- `git rm --cached` removes from the branch tree, making them show as deletions in the PR
- Restoring from main afterwards shows them as additions again (back to square one)

## The Fix

Create a clean branch from main, cherry-pick only the in-scope files:

```
git checkout -b chore/clean-branch origin/main
git checkout <dirty-branch> -- <in-scope-file1> <in-scope-file2> ...
git commit ...
git push origin chore/clean-branch
```

Then open a new PR from the clean branch. The old PR can be closed or updated.

## Verification

Use `gh pr diff <PR-number> --name-only --repo <org/repo>` to verify the final file list.

## actions/checkout SHA Note

SHA `de0fac2e4500dabe0009e67214ff5f5447ce83dd` = `v6.0.2` (confirmed via GitHub API). The `# v6.0.2` comment in tdd-gate.yml is correct.
