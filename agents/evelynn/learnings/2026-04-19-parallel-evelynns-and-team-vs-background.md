---
name: parallel-evelynns-and-disjoint-trees
description: Two Evelynns can run simultaneously from one checkout if their tree territory is disjoint.
type: pattern
---

# Parallel Evelynns — disjoint-tree rule

## What happened

2026-04-18/19 ran two Evelynn sessions concurrently from the same `~/Documents/Personal/strawberry-agents` checkout. One drove portfolio v0 (apps/portfolio/**); the other (me) drove Claude usage dashboard v1 (dashboards/usage-dashboard/** + scripts/usage-dashboard/** in strawberry-app). No cross-talk, no state races, no commit conflicts. Both streams closed cleanly on the same main.

## The rule

- Safe when tree territory is disjoint (different top-level directories, no shared config files under edit).
- Unsafe when both streams might touch the same files — git will merge them but memory/learnings races are unrecoverable.
- Both streams commit to main freely; the later committer just merges forward.
- Don't try to coordinate them directly. If they need to hand off, one closes first and the other picks up from the committed artifacts.

## Branch-from-main rule

Concrete executor rule that surfaced this session: never branch from a dependency's unmerged feature branch, even if your task depends on it. When the dependency squash-merges, GitHub deletes the shared base branch and auto-closes every child PR. Always branch from main; if your dependency isn't in main yet, wait.

## How to apply

- Parallel Evelynns are viable, not recommended as default. Before starting a second one, confirm disjoint territory.
- Mid-stream coordination across parallel Evelynns is a smell — close one before the other touches its territory.

---

*2026-04-27: original learning included a "TeamCreate vs background" section that framed background one-shots as default; that framing was inverted by the Agent Team mode mandate (`agents/memory/duong.md` §"Agent Team mode") and the section was removed. The disjoint-tree rule and branch-from-main rule above are independent of dispatch shape and remain canonical.*
