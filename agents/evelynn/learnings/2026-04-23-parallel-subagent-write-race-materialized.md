# Parallel subagent write race materialized — worktree isolation is the fix

**Date:** 2026-04-23
**Session:** c4af884e (shard c95a8d3b)

## What happened

Ekko #33 (promote) and Ekko #32 (research) were dispatched in parallel on the same working tree with no worktree isolation. Both made git commits during overlapping windows. The wrong commit was reverted by one agent, then the revert itself had to be reverted. Net result: two extra revert commits in the log, increased chance of content loss, confusion about which state was authoritative.

## Lesson

**Parallel subagent dispatches against the same working tree without `isolation: "worktree"` are a git-race waiting to happen.** The race is not theoretical — it materialized in this session. The fix is simple: include `isolation: "worktree"` on every `Agent` tool call when two or more agents may commit concurrently.

This was identified as a residual risk in the system (`assessments/residuals-and-risks/2026-04-23-parallel-subagent-writes.md`) and is now driving the `2026-04-23-subagent-worktree-and-edit-only.md` plan.

## Generalization

- Never dispatch two agents that will make git commits in parallel without `isolation: "worktree"`.
- If tasks are read-only (research, review) or emit no commits, isolation is not required but is still lower-risk.
- Worktree isolation adds a small overhead (worktree creation) but eliminates the race class entirely.

## References

- `assessments/residuals-and-risks/2026-04-23-parallel-subagent-writes.md`
- `plans/proposed/personal/2026-04-23-subagent-worktree-and-edit-only.md`
