---
name: parallel-evelynns-and-team-vs-background
description: Two Evelynns can run simultaneously from one checkout if their tree territory is disjoint. Background one-shots beat TeamCreate on serial PR→review→merge loops; TeamCreate earns its weight only when coordination/peer-DM/live-task-state is load-bearing.
type: pattern
---

# Parallel Evelynns & team-vs-background routing

## What happened

2026-04-18/19 ran two Evelynn sessions concurrently from the same `~/Documents/Personal/strawberry-agents` checkout. One drove portfolio v0 (apps/portfolio/**); the other (me) drove Claude usage dashboard v1 (dashboards/usage-dashboard/** + scripts/usage-dashboard/** in strawberry-app). No cross-talk, no state races, no commit conflicts. Both streams closed cleanly on the same main.

Separately, the dashboard stream started with a TeamCreate (`dashboard-v1`, 3 persistent teammates + reviewer) for T1-T4/T7/T8. Duong called to dissolve mid-session; T5/T6/T10 ran as background one-shots. The second half moved noticeably faster with less ceremony.

## The rules

### Parallel Evelynns
- Safe when tree territory is disjoint (different top-level directories, no shared config files under edit).
- Unsafe when both streams might touch the same files — git will merge them but memory/learnings races are unrecoverable.
- Both streams commit to main freely; the later committer just merges forward.
- Don't try to coordinate them directly. If they need to hand off, one closes first and the other picks up from the committed artifacts.

### TeamCreate vs background
- **TeamCreate** — use when agents need to peer-DM, share a live task list, or coordinate without Evelynn in the middle of every turn. Examples: 3+ agents converging on a shared surface; a reviewer/implementer ping-pong loop that would otherwise bounce through Evelynn each time; work where the task list itself is the coordination mechanism (blocking dependencies, claim-based ownership).
- **Background one-shots** (`Agent` with `run_in_background: true`) — use for serial flows: one agent builds a thing, reports, done. Next task spawns fresh. PR→review→merge loops fit this shape: each task is independent once the previous dependency merges, and Evelynn routes the next spawn herself.

The tell: if the Evelynn-in-the-middle routing is cheap (single PR link per hop), background wins. If it's expensive (many peer messages, shared state mutations, concurrent claims), TeamCreate wins.

### Branch-from-main rule
Concrete executor rule that surfaced this session: never branch from a dependency's unmerged feature branch, even if your task depends on it. When the dependency squash-merges, GitHub deletes the shared base branch and auto-closes every child PR. Always branch from main; if your dependency isn't in main yet, wait.

## How to apply

- Default to background one-shots for PR→review→merge work.
- Reach for TeamCreate when the coordination surface justifies the ceremony — 3+ agents with real shared state, not just "multiple tasks".
- Mid-stream dissolve is fine: shutdown_request → confirm terminated → spawn background agents for the rest.
- Parallel Evelynns are viable, not recommended as default. Before starting a second one, confirm disjoint territory.
