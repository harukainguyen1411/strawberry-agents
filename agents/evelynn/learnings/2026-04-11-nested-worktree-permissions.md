# Nested worktree subagent permissions

When Evelynn's session runs inside a worktree (e.g. `.claude/worktrees/agent-XXX/`), spawning subagents with `isolation: "worktree"` creates triple-nested paths where Write and Bash tools are blocked by the harness.

**Fix:** Always start Evelynn from the repo root (`~/Documents/Personal/strawberry/`). Never from a worktree. When subagents need to work on branches, either:
1. Use `isolation: "worktree"` (works when session is at repo root)
2. Or skip isolation and let the agent create its own branch via Bash

**Workaround when stuck:** Evelynn can execute directly. Duong authorized this as an override to the coordinator-only rule when subagents are blocked (S36, 2026-04-11).
