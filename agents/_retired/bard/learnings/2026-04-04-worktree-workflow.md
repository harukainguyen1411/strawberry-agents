# Git Worktree Workflow for Feature Branches

## Rule
Always use `git worktree add /tmp/strawberry-<name> -b <branch> main` for feature branch work when the main working directory has uncommitted agent state files.

## Why
Shared working directory means uncommitted files get lost on branch switch. Agent state files (evelynn's memory/learnings) are often modified but shouldn't go on feature branches.

## Pattern
```bash
git worktree add /tmp/strawberry-<feature> -b feature/<name> main
# Work in /tmp/strawberry-<feature>
cd /tmp/strawberry-<feature> && git add ... && git commit ... && git push
# Clean up
git worktree remove /tmp/strawberry-<feature>
```

Operational config (agent-network.md, .mcp.json) commits separately to main from the primary working directory.
