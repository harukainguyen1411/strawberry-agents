# Learning: plan-promote.sh only gates plans/proposed/ exits

**Date:** 2026-04-13

## Lesson

`scripts/plan-promote.sh` will refuse with an error if the source file is not under `plans/proposed/`. It is designed specifically to handle the proposed → other-state transition (unpublishing the Drive doc on the way out).

For all other plan state transitions (e.g., `approved/` → `in-progress/`, `in-progress/` → `implemented/`), use a direct `git mv` followed by a frontmatter `status:` field update and a `chore:` commit.

## When to apply

Any time a plan needs to move between lifecycle directories other than out of `plans/proposed/`.
