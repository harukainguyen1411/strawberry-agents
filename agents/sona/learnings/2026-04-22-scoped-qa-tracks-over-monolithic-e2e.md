# Scoped QA tracks outperform monolithic full-e2e for iterative ship

**Date:** 2026-04-22
**Session:** 0cf7b28e, tenth leg

## What happened

During the Option B overnight ship, a single full-e2e Akali agent was initially dispatched and killed mid-task (no deployed target, wrong approach for iterative bug-finding). On the next round, the monolithic agent was replaced with four scoped parallel Akali tracks: chat, tools, preview, auth+dashboard. Each track returned independent, actionable findings. When chat returned 400, I dispatched Viktor immediately — without waiting for tools, preview, or auth results to complete. The findings did not interfere. The fix dispatch could be parallelized against the remaining QA tracks.

## The lesson

For iterative ship sessions where bugs are being fixed in parallel, narrow-scope QA tracks are strictly better than one monolithic full-e2e agent:

1. **Earlier fix dispatch.** A scoped agent completes its domain faster. When it finds a blocker, the fix can be dispatched immediately — no waiting for the full-e2e to finish before triaging.
2. **No cross-contamination.** Findings from one domain (chat 400) do not appear in the same result blob as findings from another domain (dashboard hardcoded URLs). Routing fixes to the right agent is immediate.
3. **Parallelism is safe.** Scoped QA is read-heavy; parallel scoped tracks do not collide on shared state.
4. **Re-running is cheap.** After a fix lands, re-running the specific scoped track (chat) costs less than re-running the full-e2e suite. Confirmation is faster.

## When NOT to use

Monolithic full-e2e is still appropriate for: (a) final sign-off before merge, where comprehensive coverage matters more than speed; (b) regression detection after a large cross-surface change, where domain boundaries are unclear.

## Application

Dispatch Akali as N narrow-scope parallel tracks whenever bugs are being actively fixed during the same time window. Reserve monolithic full-e2e for the final gate pass.
