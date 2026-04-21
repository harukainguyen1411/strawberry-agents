---
status: proposed
owner: pyke
date: 2026-04-14
title: Git status cleanup — worktrees, artifacts, gitignore gaps
---

# Git Status Cleanup

Duong flagged the working tree is cluttered. This plan groups cleanup actions by risk level.

---

## Group 1: Zero-risk gitignore additions

Add these patterns to `.gitignore`. None of these are tracked; adding them just silences `git status`.

```gitignore
# Build artifacts (turbo, firebase, playwright)
.turbo/
.firebase/
.playwright-mcp/
apps/functions/lib/

# Claude session sentinels (ephemeral, created by SubagentStop hook)
.claude/*.sentinel

# Claude agent worktrees (managed by Claude Code, not user worktrees)
.claude/worktrees/

# Stray logs
firebase-debug.log
```

**Steps:**
1. Append the above block to `.gitignore`.
2. `git add .gitignore && git commit -m "chore: gitignore build artifacts, sentinels, claude worktrees"`.

---

## Group 2: Low-risk — delete stray files

These are one-off screenshots and debug logs sitting in the repo root. No value in keeping them.

| File | Action | Reason |
|------|--------|--------|
| `apps-darkstrawberry-check.png` | `rm` | One-off screenshot, no references |
| `myapps-screenshot.png` | `rm` | One-off screenshot, no references |
| `firebase-debug.log` | `rm` | Runtime log, no value |
| `.claude/katarina-session-end.sentinel` | `rm` | Stale sentinel from past session |
| `.claude/ornn-session-end.sentinel` | `rm` | Stale sentinel from past session |
| `.claude/swain-session-end.sentinel` | `rm` | Stale sentinel from past session |

**Steps:**
1. Delete the files listed above.
2. Confirm they are now hidden by gitignore (sentinels, log) or gone (screenshots).

No commit needed — these are untracked. Gitignore from Group 1 prevents recurrence of sentinels and logs.

---

## Group 3: Low-risk — commit uncommitted real work

These files look like real work from the UBCS slide project and Evelynn journaling:

| File | Status | Action |
|------|--------|--------|
| `agents/evelynn/journal/cli-2026-04-13.md` | staged (A) | Already staged. Journals are gitignored — **unstage** with `git reset HEAD` so gitignore takes effect. |
| `agents/evelynn/transcripts/2026-04-13-78b54f57.md` | staged (A) | Commit — transcript archives ARE committed per gitignore rules. |
| `tools/ubcs-slide-builder.py` | modified (M) | Commit the modification. |
| `tools/ubcs-data-parser.py` | untracked | Commit — new UBCS tooling. |
| `tools/ubcs-slide-builder-v2.py` | untracked | Commit — new UBCS tooling. |
| `plans/approved/2026-04-13-ubcs-slide-team.md` | untracked | Commit — approved plan belongs in git. |

**Steps:**
1. `git reset HEAD agents/evelynn/journal/cli-2026-04-13.md` (unstage — journals are gitignored).
2. `git add agents/evelynn/transcripts/2026-04-13-78b54f57.md tools/ubcs-slide-builder.py tools/ubcs-data-parser.py tools/ubcs-slide-builder-v2.py plans/approved/2026-04-13-ubcs-slide-team.md`
3. `git commit -m "chore: commit UBCS slide tools, approved plan, and Evelynn transcript from 2026-04-13"`

---

## Group 4: Medium-risk — prune merged worktrees

The following `.worktrees/` branches appear in `git branch -r --merged main`, meaning their remote branches are fully merged. The worktrees can be removed.

| Worktree dir | Branch | Merged? |
|---|---|---|
| `.worktrees/feat-bee-github-rearchitect` | `feat/bee-github-rearchitect` | Yes (remote merged) |
| `.worktrees/feat-bee-mvp-b1-b7` | `feat/bee-mvp-b1-b7` | Yes |
| `.worktrees/feat-bee-mvp-b4` | `feat/bee-mvp-b4` | Yes |
| `.worktrees/feat-bee-mvp-b5` | `feat/bee-mvp-b5` | Yes |
| `.worktrees/feat-bee-mvp-b6` | `feat/bee-mvp-b6` | Yes |
| `.worktrees/feat-bee-mvp-b8` | `feat/bee-mvp-b8` | Yes |
| `.worktrees/feat-feature-flags-remote-config` | `feat-feature-flags-remote-config` | Yes |
| `.worktrees/feat-feedback-loop-phase-ab` | `feat/feedback-loop-phase-ab` | Yes |
| `.worktrees/feat-windows-push-autodeploy` | `feat/windows-push-autodeploy` | Yes |
| `.worktrees/fix-bee-storage-rules` | `fix-bee-storage-rules` | Yes |

**Steps (for each worktree above):**
1. `git worktree remove .worktrees/<dir> --force`
2. `git branch -d <local-branch>` (if local branch exists)

Also prune Claude-managed worktrees under `.claude/worktrees/` — these are ephemeral agent worktrees that accumulate. Run:
```bash
git worktree list | grep '.claude/worktrees/' | awk '{print $1}' | xargs -I{} git worktree remove {} --force
```

---

## Group 5: Medium-risk — assess unmerged worktrees

These worktrees have branches NOT merged into main. The executor should **not** remove them without Duong's confirmation. List them for Duong to review:

| Worktree dir | Branch | Notes |
|---|---|---|
| `.worktrees/feat-bee-gemini-intake` | `feat-bee-gemini-intake` | Active bee feature |
| `.worktrees/feat-caching-fix` | `feat-caching-fix` | Not merged |
| `.worktrees/feat-deploy-lockdown` | `feat-deploy-lockdown` | PR #102 pending (Pyke reviewed, ship it) |
| `.worktrees/feat-deployment-architecture` | `feat/deployment-architecture` | Not merged |
| `.worktrees/feat-platform-monorepo` | `feat/platform-monorepo` | Not merged |
| `.worktrees/feat-subagent-stop-hook` | `feat/subagent-stop-hook` | Not merged |
| `.worktrees/feat-discord-per-app-channels` | `feat/discord-per-app-channels` | Merged per remote, but worktree not in git status — check if already gitignored |
| `.worktrees/retro-skill-body-strip` | `retro-skill-body-strip` | Not merged |

**Action:** Flag these to Duong. For each, he decides: merge/close the PR and prune, or keep the worktree.

---

## Group 6: Optional — add `.worktrees/` to gitignore

Currently `.worktrees/` dirs show as untracked. Add to `.gitignore`:

```gitignore
# User worktrees (managed by git worktree, not tracked)
.worktrees/
```

Include this in the Group 1 gitignore commit.

---

## Expected outcome

After all groups complete, `git status` should show only:
- Clean working tree (nothing staged, nothing modified)
- Untracked files: none visible (all gitignored)

Worktree count drops from ~24 to ~8 (unmerged only), pending Duong's decisions on Group 5.
