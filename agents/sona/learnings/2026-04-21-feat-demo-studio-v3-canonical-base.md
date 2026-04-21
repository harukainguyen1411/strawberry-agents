# feat/demo-studio-v3 is the canonical impl base for all demo-studio-v3 work

**Date:** 2026-04-21
**Context:** Wave 1 impl dispatch (fifth leg, ship-day). Second dispatch failed because subagents based on `origin/main` instead of `feat/demo-studio-v3`.

## What happened

Wave 1 second dispatch: impl agents pulled from `origin/main` as their starting point. The `feat/demo-studio-v3` branch is 474 commits ahead of main — it carries all current Wave 1–4 planned changes, existing service scaffolding, and integration test state. Working on `origin/main` produces stale code surface, missing service scaffolding, and invalid test targets. The agents' output would have been targeting the wrong codebase state.

## The lesson

**`feat/demo-studio-v3` is the canonical long-lived feature branch for all demo-studio-v3 implementation work.** Every impl agent dispatched for this product area must:
1. Explicitly be told to check out `feat/demo-studio-v3` (not `origin/main`, not `main`)
2. Confirm their working tree HEAD matches this branch before starting implementation
3. Create their own worktree or branch off `feat/demo-studio-v3` for the specific task

Coordinator must include branch name explicitly in every impl delegation prompt for demo-studio-v3 work. Do not assume agents will discover the correct base.

## Why this matters

A long-lived feature branch 474 commits ahead of main is a fundamentally different codebase surface. Impl on the wrong base means: wrong imports, missing modules, API signatures that don't exist yet or were changed, and tests that reference stubs not present on main.
