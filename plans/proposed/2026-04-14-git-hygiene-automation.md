---
status: proposed
owner: pyke
date: 2026-04-14
title: Git hygiene automation — worktree cleanup, gitignore enforcement, periodic sweep
---

# Git Hygiene Automation

**Problem:** 15+ stale worktrees accumulated in 3 days. Build artifacts from new tools pollute `git status`. No automated cleanup exists. The earlier plan (2026-04-14-git-status-cleanup) handles the one-time cleanup; this plan prevents recurrence.

**Approach:** Three layers of defense — automated worktree reaping, gitignore enforcement at tool-creation time, and a session-start hygiene sweep.

---

## Deliverable 1: `scripts/prune-worktrees.sh` — automated worktree reaper

A POSIX-portable script that identifies and removes worktrees whose branches are fully merged into main (or whose remote branch has been deleted).

**Behavior:**

1. Run `git worktree list --porcelain` to enumerate all worktrees.
2. For each worktree (excluding the main working tree):
   - Extract the branch name.
   - Check if the branch is merged into `main` (`git branch --merged main | grep <branch>`).
   - Check if the remote branch still exists (`git ls-remote --heads origin <branch>`).
   - If merged OR remote-deleted: mark as stale.
3. In `--dry-run` mode (default): print the list of stale worktrees and what would be removed.
4. In `--prune` mode: run `git worktree remove <path> --force` and `git branch -d <branch>` for each stale worktree. Print each removal.
5. Always skip worktrees with uncommitted changes (check `git -C <path> status --porcelain`).
6. Handle both `.worktrees/` and `.claude/worktrees/` paths.

**Interface:**
```
bash scripts/prune-worktrees.sh           # dry-run, list stale worktrees
bash scripts/prune-worktrees.sh --prune   # actually remove them
```

**Files to create:**
- `scripts/prune-worktrees.sh`

**Tests:** Run in dry-run mode against the current repo (18 worktrees). Verify it correctly identifies the 10 known-merged worktrees from the cleanup plan. Verify it does NOT flag unmerged worktrees like `feat-bee-gemini-intake`.

---

## Deliverable 2: Session-start hygiene check in `agents/health/heartbeat.sh`

Add a worktree-stale-count check to the existing heartbeat script. This runs at Evelynn session start.

**Behavior:**

1. At the end of `heartbeat.sh`, call `scripts/prune-worktrees.sh` (dry-run mode).
2. If stale worktree count > 0, print a warning: `WARNING: N stale worktrees detected. Run 'bash scripts/prune-worktrees.sh --prune' to clean up.`
3. Do NOT auto-prune. The heartbeat is informational — Evelynn or Duong decides to act.

**Files to modify:**
- `agents/health/heartbeat.sh` — append the stale-worktree check block.

---

## Deliverable 3: Worktree cleanup hook in `/end-subagent-session` skill

When an agent's session ends and its PR has been merged, the agent's worktree is dead weight. Add cleanup logic to the end-subagent-session skill.

**Behavior:**

1. After the existing commit/memory/learnings steps, detect the agent's current working directory.
2. If the cwd is inside a `.worktrees/` or `.claude/worktrees/` path:
   - Check if the branch is merged into main (fetch + check).
   - If merged: run `git worktree remove <path> --force` from the main worktree. Print confirmation.
   - If NOT merged: do nothing. The worktree stays for future work.
3. If the cwd is the main worktree: skip (nothing to clean).

**Constraint:** This runs inside a subagent that may be inside the worktree being removed. The removal command must execute from the main repo root, not from inside the worktree. Use `git -C <main-repo-root> worktree remove <path>`.

**Files to modify:**
- `.claude/skills/end-subagent-session/` — the skill definition (add post-session worktree cleanup section).

**Risk:** Medium. If the subagent's shell is still inside the worktree when it gets removed, the final commands may fail. Mitigation: `cd` to the main repo root before running removal. If removal fails, log a warning and continue (non-blocking).

---

## Deliverable 4: Gitignore-on-first-use enforcement

When a new tool or app directory is introduced, build artifacts must be gitignored from the start. This is a process rule, not a script — but it needs a checkable enforcement point.

**Approach A (preferred): Pre-commit hook check.**

Add a check to the existing pre-commit hook (or create one if none exists for this) that warns if common build artifact patterns are being committed:

- `**/node_modules/`
- `**/.turbo/`
- `**/.firebase/`
- `**/dist/` (unless explicitly tracked)
- `**/lib/` under `apps/functions/`
- `**/__pycache__/`

If any staged file matches these patterns, block the commit with a message: `BLOCKED: Staged file matches build artifact pattern: <path>. Add to .gitignore or use git add --force if intentional.`

**Approach B (lighter): Architecture doc rule.**

Add a section to `architecture/git-workflow.md` under Hard Rules:
> When creating a new tool or app directory, add its build output patterns to `.gitignore` in the same commit that creates the directory.

**Recommended:** Do both. The pre-commit hook catches mistakes; the doc rule sets expectations.

**Files to create/modify:**
- `.claude/hooks/` or `.git/hooks/pre-commit` — add artifact pattern check.
- `architecture/git-workflow.md` — add the gitignore-on-first-use rule.

---

## Deliverable 5: Gitignore gap coverage

Add patterns that are currently missing from `.gitignore`. These were identified in the cleanup plan but should be permanent.

**Patterns to add:**

```gitignore
# Worktrees (managed by git worktree, not tracked)
.worktrees/

# Build artifacts
.turbo/
.firebase/
.playwright-mcp/
apps/functions/lib/

# Claude session sentinels (ephemeral)
.claude/*.sentinel

# Claude-managed worktrees
.claude/worktrees/

# Runtime logs at repo root
firebase-debug.log

# Per-app turbo caches (catch-all for nested .turbo)
**/.turbo/
```

**Files to modify:**
- `.gitignore`

---

## Execution order

1. **Deliverable 5** first (gitignore gaps) — immediate noise reduction, zero risk.
2. **Deliverable 1** (prune-worktrees.sh) — the core script everything else depends on.
3. **Deliverable 2** (heartbeat integration) — wires the script into session start.
4. **Deliverable 4** (pre-commit hook + doc rule) — prevents future gitignore gaps.
5. **Deliverable 3** (end-subagent-session integration) — agent self-cleanup, highest complexity.

Each deliverable is independently committable and testable.

---

## What this does NOT cover

- **GitHub Actions post-merge cleanup:** Not feasible in this system. PRs are merged via GitHub web UI, and there is no server-side hook that can reach the local machine to remove worktrees. The heartbeat check + end-subagent-session hook cover this gap instead.
- **Automatic deletion of unmerged worktrees:** Intentionally excluded. Unmerged worktrees may contain active work. The script only touches merged/orphaned branches.
- **Windows parity for `.claude/worktrees/`:** Claude Code manages `.claude/worktrees/` internally. The prune script handles them, but Claude Code may recreate them. This is acceptable — the script is idempotent.
