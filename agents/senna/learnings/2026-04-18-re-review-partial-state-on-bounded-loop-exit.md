# Learning: Bounded loop exit does not prevent partial state

**Date:** 2026-04-18
**PR:** #144 (evelynn memory sharding re-review)

## Finding

A bounded loop (max 100 iterations, exit 1 on exhaustion) resolves an unbounded-loop bug
but does not protect against partial state if the loop is nested inside a larger
sequential operation that has already made side effects.

In `evelynn-memory-consolidate.sh`, the UUID collision loop fires per-shard inside the
outer `SORTED_SHARDS` loop. If collision exhaustion triggers on shard N, shards 1..N-1
are already `git mv`'d and `evelynn.md` is already rewritten. The loud `exit 1` fires
into the cleanup trap (which runs), but no rollback of the partial git state occurs.

## Lesson

When flagging an unbounded loop, also check whether bounding it is sufficient — or
whether the abort path needs a rollback mechanism to avoid partial state. The two fixes
are independent: bounding the loop is necessary but may not be sufficient.

## Disposition

Flagged as a residual structural note in the re-review comment (not a blocker for merge
since the original finding was specifically about the unbounded loop).
