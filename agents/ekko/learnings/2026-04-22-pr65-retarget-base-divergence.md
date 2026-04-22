# PR #65 Retarget — Base Branch Divergence Flag

**Date:** 2026-04-22
**Task:** Retarget feat/demo-dashboard-split PR from main → feat/demo-studio-v3

## What happened

PR #65 (feat/demo-dashboard-split W1 scaffold, 3 commits, 8 files in tools/demo-dashboard/) was retargeted from `main` to `feat/demo-studio-v3` successfully via `gh pr edit 65 --base feat/demo-studio-v3`.

## The problem discovered

The merge-base of `feat/demo-dashboard-split` (cut from main @ `afdf1a8`) and `feat/demo-studio-v3` is `4cdbd3c` — much older than `afdf1a8`. This means:

- `feat/demo-studio-v3` has never had the main-branch service work merged into it (`tools/demo-studio-config-mgmt/`, `tools/demo-studio-factory/`, `tools/demo-studio-schema/`, `tools/demo-studio-verification/`, CI workflows).
- `feat/demo-studio-v3` uses a **renamed service tree** (`tools/demo-config-mgmt`, `tools/demo-factory`, `tools/demo-preview`, etc.) that is entirely different from the `tools/demo-studio-*` naming on main.

Result: PR diff became 132 files / 27,779 insertions instead of 8 files / 127 insertions.

## Lesson

Before retargeting a PR, check the merge-base of head vs proposed-new-base — not just the divergence from the old base. If the new base has a much older shared ancestor, the PR diff will balloon with the delta between the two branch histories.

Correct check: `git merge-base origin/<head-branch> origin/<new-base-branch>`

## Recommended unblock

1. Merge main → feat/demo-studio-v3 first, then this PR shows only W1.
2. OR cherry-pick the 3 W1 commits (a72d64e, fede8ac, cb57ce6) onto a new branch off feat/demo-studio-v3 HEAD and open a fresh PR.
