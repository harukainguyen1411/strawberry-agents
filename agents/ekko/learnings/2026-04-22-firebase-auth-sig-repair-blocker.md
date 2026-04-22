# Learnings: Firebase Auth Plan Signature Repair — Blocker Analysis

Date: 2026-04-22
Session: Ekko — Sona dispatch (firebase-auth sig repair)

## Summary

Attempted to repair invalidated approved + in_progress signatures on `plans/in-progress/work/2026-04-22-firebase-auth-for-demo-studio.md` after Aphelios inlined 47 tasks (commit dbc8803). The approved gate passed and the signature was committed. Promotion to approved succeeded. The in_progress sign step is BLOCKED.

## Root Cause

The demotion approach created a stale file at `plans/approved/work/` (commit `b03d2c4`) with the old signature and old body. When the subsequent promote commit (`05ec5c5`) ran `git mv plans/proposed/... plans/approved/...`, git saw this as modifying the existing `plans/approved/work/` file (status M) rather than creating a new file (status A). This is because the approved file already existed from the demotion step.

The verify script (`orianna-verify-signature.sh`) discovers the signing commit by walking `git log --follow` for the plan's current path. When the path is `plans/approved/work/...`, it finds commit `05ec5c5` (the promote commit) as the one that "added" `orianna_signature_approved:` — because:
1. The parent of `05ec5c5` (the sign commit `c0cbda5`) only has the file at `plans/proposed/work/` — NOT at `plans/approved/work/`
2. So `git show c0cbda5:plans/approved/work/...` returns empty → `parent_has_field = 0`
3. The verify script identifies the promote commit as the signing commit → wrong author email → verify fails

The true sign commit (`c0cbda5`, orianna author) is only visible in the `plans/proposed/work/...` history, not in the `plans/approved/work/...` history, because `--follow` fails to bridge the rename (too many changed lines in the promote commit, similarity below git's rename threshold).

## What Went Wrong in Demotion Approach

The CORRECT demotion approach (used in MAD+BD re-sign) was:
1. Move plan to `plans/proposed/work/` via git mv (don't create an intermediate `plans/approved/work/` file)
2. Remove signatures, commit
3. Sign approved (plan at proposed/)
4. Promote proposed → approved via plan-promote.sh (file created fresh at approved/ as 'A' not 'M')
5. Sign in_progress (plan at approved/)
6. Promote approved → in-progress via plan-promote.sh

My mistake: I did an intermediate step that created the file at `plans/approved/work/` (the "demote" commit) before moving to `plans/proposed/work/`. This left a ghost file at approved/ that corrupted the subsequent promote flow.

## Current State

- Plan at: `plans/approved/work/2026-04-22-firebase-auth-for-demo-studio.md`
- `orianna_signature_approved`: hash=`91a431b7ed3f69b260755586908979245602a06e9d3e815d9ba432790d232d86` (body valid, but sign commit verification fails)
- `orianna_signature_in_progress`: not yet present
- Last pushed commit: `adf004a`

## Repair Options for Duong/Evelynn

**Option A: Orianna-Bypass trailer (fastest)**
  - Edit plan body (no change needed — body is correct)
  - Run orianna-sign.sh for in_progress while at approved/ — it will fail on carry-forward
  - Use `Orianna-Bypass: stale approved sig from rename ambiguity — body hash valid` commit trailer on a manual commit that adds the in_progress sig line
  - Requires harukainguyen1411 admin identity per §D9.1
  - Then promote to in-progress via plan-promote.sh with `NO_PUSH=1` to avoid the verify blocking

**Option B: Clean re-sign from scratch (slower but correct)**
  - git mv `plans/approved/work/...` back to a temp name to clear the path history
  - Force-delete both copies (requires coordination)
  - Recommit the plan clean at `plans/proposed/work/` with no signatures
  - Sign approved (fresh, no history conflict)
  - Promote to approved (file is 'A' at approved/ path)
  - Sign in_progress
  - Promote to in-progress

**Option C: Fix orianna-verify-signature.sh**
  - The verify script should also search the parent paths (via git log --follow on old paths) when the current path log doesn't find the signing commit
  - But modifying the verify script is out of Ekko scope

## Key Learning

When demoting a plan for re-sign, NEVER create an intermediate file at the target directory. The ONLY correct demotion path is:
  - git mv in-progress → proposed (single mv, no intermediate)
  - Remove sigs, update status to proposed, commit once
  - Then follow the normal sign chain

The intermediate stop at `approved/` before `proposed/` was the mistake.
