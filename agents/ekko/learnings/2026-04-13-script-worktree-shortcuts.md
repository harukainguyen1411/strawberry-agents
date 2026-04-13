# Script shortcuts for worktree creation

## safe-checkout.sh interactive stdin problem

`scripts/safe-checkout.sh` uses `read -p` to prompt on untracked files. In subagent (non-TTY) context this hangs or fails. Do NOT pipe `y` or use `--force` — the script doesn't support that.

**Correct approach in subagent context:**

```bash
git worktree add .worktrees/<branch-name> -b <branch-name>
```

This bypasses the script entirely and is safe when you're creating a new branch (no risk of overwriting tracked files).

## plan-promote.sh scope

`scripts/plan-promote.sh` only operates on `plans/proposed/*.md` — it unpublishes Drive docs. For plans already in `approved/` or `in-progress/`, use manual git mv + edit the `status:` frontmatter field directly.

Pattern:
```bash
git mv plans/approved/<plan>.md plans/in-progress/<plan>.md
# edit status: field
git add plans/ && git commit -m "chore: promote <plan> to in-progress"
```
