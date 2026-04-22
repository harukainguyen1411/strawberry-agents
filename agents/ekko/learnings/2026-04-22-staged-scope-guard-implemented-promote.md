# 2026-04-22 — staged-scope-guard-hook implemented promotion

## Context

Promoting `2026-04-21-staged-scope-guard-hook.md` from in-progress to implemented via full re-sign chain.

## Key learnings

1. **## Test results requires an `assessments/` path, not just a PR ref.** The implementation-gate-check Step C looks for either a CI URL or a path under `assessments/`. A bare "PR #17 (merge e58a96d)" token is not sufficient — add `assessments/plan-fact-checks/<fact-check>.md` reference to satisfy the gate.

2. **Body edits after orianna-sign.sh always require a full re-sign cycle from proposed.** Even a single-line addition (adding an assessments path to Test results) invalidates both approved and in_progress hashes. Recovery: strip both sig fields, set status: proposed, move file to proposed/personal/, commit, then re-sign approved → promote → sign in_progress → promote → sign implemented → promote.

3. **`git restore --staged .` before every orianna-sign.sh call.** Parallel agents can leave staged files in the index. The staged-scope body-fix pattern: edit → restore staged → add plan only → commit → sign → promote.

4. **plan-promote.sh pushes on each hop and can leave a dangling deletion in the working tree.** After promote to in-progress pushed, the working-tree copy of the approved plan gets removed by plan-promote.sh. If a concurrent agent then also removes the in-progress copy, you end up with the plan file absent from the working tree but still in HEAD. Stage the deletion explicitly with `git add -u` before committing the next body fix.

5. **Re-sign chain SHAs for this session:**
   - body fix + move to proposed: `374fbde`
   - approved sig: `66e50fd`
   - approved promote: `ca5523c`
   - in_progress sig: `939373b`
   - in-progress promote: `70fc65a`
   - implemented sig: `b927b72`
   - implemented promote: `316949a`
