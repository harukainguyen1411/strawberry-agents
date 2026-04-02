# Personal Agent System

This is Duong's personal agent workspace — separate from the work agent system at `workspace/agents/`.

## Scope

Personal tasks only: life admin, personal projects, learning, side projects. Work tasks go through the work agent system.

## Git

- Each top-level folder is its own repo
- Never include AI authoring references in commits
- Never use `git rebase` — always merge
- Avoid shell approval prompts (no quoted strings, no `$()`, no globs in bash)

## Plans

Plan files go in `plans/` with format `YYYY-MM-DD-<slug>.md` and YAML frontmatter (status, owner).
