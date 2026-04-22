# All demo-studio-v3 PRs must target feat/demo-studio-v3 (god branch), not main

**Date:** 2026-04-22
**Session:** 1423e23d-e7aa-41ee-9558-fa5f6deed2b3 (twelfth leg)
**Concern:** work

## Observation

PR #65 (dashboard-split W1) was initially opened against `main`. Duong corrected: all demo-studio-v3 implementation work targets `feat/demo-studio-v3` (the god branch), which is 474+ commits ahead of main. Retargeting after the fact caused a 20+ commit drift problem — the PR showed 132 files / 27,779 insertions because `feat/demo-dashboard-split` was cut from `main`, not from the god branch.

## Rule

When dispatching any builder agent (Viktor, Jayce, Talon, Soraka) for demo-studio-v3 work:
1. The feature branch must be cut from `feat/demo-studio-v3`, not from `main`.
2. The PR must target `feat/demo-studio-v3` as base.
3. Explicitly inject the base branch in every builder task prompt: "cut your branch from `feat/demo-studio-v3`, PR base is `feat/demo-studio-v3`."

If a branch was cut from `main` and must be retargeted, the cost is a conflict resolution merge (Viktor task #33 pattern) — measurable overhead. Prevention is trivially cheap.

## Generalizes to

Any multi-service repo where a long-running integration branch diverges significantly from main. Always anchor feature branches to the active integration base, not the repo default.
