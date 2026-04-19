# Reviewer Lane Dry-Run Pattern (Phase 4 of reviewer-identity-split)

Date: 2026-04-19

## Pattern

When validating a new reviewer lane before wiring it into agent defs, use a throwaway PR:

1. Create branch via `git worktree add` (safe-checkout.sh blocks on untracked files — worktree add does not).
2. Push + open PR. Then test both lanes independently before checking distinct-reviewer attribution.
3. Verify with `gh pr view <n> --json reviews --jq '[.reviews[] | {author:.author.login, state:.state}]'` — must show two distinct `author` values.
4. Close PR without merging; delete remote branch via `gh api -X DELETE .../git/refs/heads/<branch>`.
5. Remove worktree and local branch after remote deletion.

## Key constraint

`safe-checkout.sh` exits non-zero when untracked files are present in the working tree (Rule 1 guard).
`git worktree add` does not share this guard — use it directly when the working tree has committed-but-untracked assessments or other gitignored files.

## GitHub two-reviewer confirmation

GitHub models reviews as per-user slots. Two accounts submitting APPROVED = two entries in `.reviews[]`.
Confirmed: `strawberry-reviewers-2` (Senna) and `strawberry-reviewers` (Lucian) are counted as distinct reviewers.
This is the structural prerequisite for the 2-approval gate in Phase 7.
