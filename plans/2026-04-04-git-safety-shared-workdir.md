---
status: proposed
owner: pyke
date: 2026-04-04
---

# Git Safety — Shared Working Directory

## Problem

Multiple agents share one working directory. When any agent runs `git checkout`, `git stash pop`, or `git reset`, it changes the working tree for ALL agents. Uncommitted files from other agents get silently lost.

**Incidents:**
- 2026-04-04: Syndra's plan file wiped by another agent's branch switch (stash/checkout/pop)
- 2026-04-04 (earlier): Memory wipe from auto-resolving merge conflicts

## Root Cause

Shared working directory + multiple concurrent agents + git = data loss. Git has no concept of per-user uncommitted state in a single worktree.

## Prevention Plan

### Layer 1 — Commit Immediately (protocol rule)

**Impact: highest. Cost: zero.**

Agents must commit their work within the same turn they create it. Never leave files uncommitted between tool calls that involve branch switching.

Add to agent-network.md:

> Never leave work uncommitted. If you create or modify a file, commit it before doing anything else with git (checkout, stash, pull, merge). Uncommitted files in a shared working directory WILL be lost when another agent switches branches.

### Layer 2 — Git Worktrees for Concurrent Branch Work

When an agent needs to work on a feature branch while others are on main, use `git worktree` instead of `git checkout`:

```bash
git worktree add /tmp/strawberry-feature-xyz feature/xyz
# Work in /tmp/strawberry-feature-xyz — doesn't touch the main working tree
git worktree remove /tmp/strawberry-feature-xyz
```

Each branch gets its own directory. No checkout, no stash, no conflicts. The main working directory stays on main.

**Trade-off:** Adds complexity. Only needed when multiple agents actively work on different branches simultaneously.

### Layer 3 — Safe Checkout Wrapper

Git doesn't have a native pre-checkout hook. Instead, provide a wrapper script (`scripts/safe-checkout.sh`) that checks for uncommitted files before switching branches. Agents use this instead of raw `git checkout`.

**Trade-off:** Nice to have. Implement if violations keep happening despite Layer 1.

## Recommendation

1. **Layer 1** — implement now. Add the protocol rule to agent-network.md and GIT_WORKFLOW.md.
2. **Layer 2** — document as the approach for concurrent branch work. Add to GIT_WORKFLOW.md.
3. **Layer 3** — defer unless Layer 1 proves insufficient.

## Effort

Layer 1: ~5 minutes (doc updates). Layer 2: ~10 minutes (docs + optional wrapper). Layer 3: ~15 minutes.
