# 2026-04-24 — subagent-merge-back polish (PR #38)

## Context

Four non-blocking polish fixes from Senna's PR #37 review, applied to `scripts/subagent-merge-back.sh`.

## Fix patterns

### Fix 1 — Pipe swallows push failure
`git push origin main 2>&1 | while IFS= read -r line; do ...; done` — under `set -e`, the exit status is the while loop's, not git's. Append `|| warn "..."` after the done to surface failures.

### Fix 2 — `|| true` swallows non-conflict merge errors
Old: `git merge --no-ff ... || true` — any non-zero exit becomes a "clean merge".
New: Capture HEAD before + exit status after. If exit != 0 AND HEAD unchanged AND no conflict markers → emit specific error. If conflict markers present → fall through to conflict handling.

### Fix 3 — `for f in $VAR` word-splits on whitespace
Filenames with spaces mis-bucket. Replace with:
```sh
while IFS= read -r f; do
    case "$f" in ...
done <<EOF
$(git diff --name-only --diff-filter=U)
EOF
```
The heredoc feeds lines into the while loop in the current shell (variables persist after loop — no subshell issue). Works POSIX-portably without process substitution.

Note: `read -d ''` + `-z` null-terminated approach requires process substitution (`< <(...)`), which is bash-specific. The heredoc approach with `read -r` handles space-in-filename correctly and is more portable.

### Fix 4 — Dead variable
`HAS_OTHER_CONFLICT` was set in the old loop but never read (all paths called `die`). Simply remove it.

## Worktree/branch note
- Branched off main at `215a76fd` via `git worktree add` (safe-checkout.sh refused due to untracked files in main working tree).
- Worktree at `/Users/duongntd99/Documents/Personal/strawberry-worktrees/merge-back-polish`.
- `215a76fd` was a pre-branch commit required to clear the `plans/implemented/personal/2026-04-24-custom-slack-mcp.md` modification (Rule 1: never leave uncommitted work).

## Tests
6/6 passing in `test-parallel-worktree-merge-back.sh`. Pre-existing failures in `test-agent-default-isolation*.sh` are unrelated to this change.
