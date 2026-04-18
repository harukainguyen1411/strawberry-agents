# Fresh clone as migration smoke test

**Date:** 2026-04-19
**Session:** S50

## Lesson

Repo migrations aren't done when the remote is pushed. They're done when a *fresh clone* of the new remote has every file the next session will need. Until then, the old checkout is silently authoritative and the new remote is a stale snapshot.

## What happened

S49 finished the public-repo migration sequence A1–A3: filter the tree, push `harukainguyen1411/strawberry-agents`, declare the migration complete-pending-A4. We kept working from `~/Documents/Personal/strawberry` (the old archive checkout) for the rest of S49 and tonight's S50 startup. Every commit went to `Duongntd/strawberry` (archive). None of those commits — including S48 close, S49 close, the entire identity-cascade fix, plan promotions, learnings — replicated to strawberry-agents.

Duong then cloned strawberry-agents to a new path and opened a fresh Evelynn session there. She had no memory of S48 or S49. Visibly amnesiac in her first reply.

Fix: rsync agent-infra paths from old → new, commit `6858d16`, push. Took Ekko one short background spawn. But the gap could have been weeks if Duong hadn't tried the new path tonight.

## Pattern to apply

When migrating a repo split, treat A-phases as not-done until you've run this checklist:

1. Push the new remote (e.g. A3).
2. Clone the new remote to a temporary path (`/tmp/migration-smoke`).
3. Diff the temp clone against the working checkout: `diff -rq /tmp/migration-smoke ~/Documents/.../old-checkout` for the in-scope paths.
4. Any deltas mean the new remote is stale → sync before declaring done.
5. Only then promote the new path as canonical.

## When to apply

- Any time a repo is created via `filter-repo` or migration script and pushed to a new remote.
- Any time a checkout is going to be swapped to a different working tree.
- Any time multiple repos share state and only one is the active push target.

## Anti-pattern

Calling A4 "the local checkout swap" treats the swap as the closing step when it's actually the *exposure* step. The closing step is verifying the new clone is current. Without that verification, the swap surfaces the gap instead of closing it.
