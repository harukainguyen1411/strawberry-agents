# filter-repo from a stale clone snapshots clone-time state

**Date:** 2026-04-27
**Context:** Recovery from a security incident where Senna's leak audit returned FAIL CRITICAL on the public-repo flip. Ekko ran `git filter-repo` to scrub leaked secrets and force-pushed the cleaned history.

## What happened

I authored ADR amendments 2 (`8ef6bad1`) and 3 (`b6ff1224`) on main, pushed both successfully, got "On hold" notice ~7-15 minutes later, then on resume found origin/main HEAD had a different ADR file: only amendment 1 (the §D6.1 entry) was present; amendments 2 and 3 were absent from the file body, the §Amendment log, and the schema sketch (AUTOINCREMENT was back, `learnings.coordinator` column was missing, §D3.1 didn't exist).

The original commits weren't garbage-collected — they still existed in the local object database with intact content and messages, but they were unreachable from origin/main because the rewritten history path didn't include them.

## Root cause (per team-lead's independent confirmation)

Ekko's filter-repo session probably ran from a fresh clone made *before* my amendments were authored. filter-repo operates on the snapshot at clone-time, not at rewrite-time — so any commits authored on the upstream main *after* the clone was made are silently absent from the rewritten history that gets force-pushed back. The pushed result is "scrubbed but stale."

## Generalizable lesson

**filter-repo (and any history-surgery tool) operates on the snapshot it was given, not on the live upstream.** If the snapshot was taken at time T0 and other commits land at T1 > T0, those T1 commits are silently lost when the rewritten T0-snapshot history is force-pushed.

## What to do about it

1. **Before running filter-repo**, fetch the latest main and confirm the clone HEAD matches origin/main HEAD. If not, refresh the clone or warn loudly.
2. **After force-pushing a rewrite**, diff the post-rewrite main against pre-rewrite main and surface any commits present in the latter but absent in the former. Those are collateral-damage candidates that need re-authoring.
3. **As an author whose work might be in the lost set**, check `git log --oneline <my-file>` for your recent SHAs after a history rewrite is announced. If they're absent from origin/main, the original commits still exist locally as dangling refs (recoverable via reflog) — re-author rather than cherry-pick (cherry-pick produces new SHAs anyway and re-author lets you write a coherent commit message acknowledging the lineage).
4. **Re-author commits should explicitly note the lost SHA** in the commit body so future blame-readers have a pointer to the original authoring intent. Pattern: "Re-authored after Ekko's history-rewrite session made the original commit `<SHA>` unreachable from origin/main. Content verbatim from the original; semantic intent and reviewer attribution preserved."

## What NOT to do

- Don't reach for force-push to "fix" the post-rewrite state by overwriting it with your local copy — you'd destroy the security-scrub work that made the rewrite necessary.
- Don't cherry-pick the dangling SHAs blindly — they're disconnected from the new history; cherry-picking creates new SHAs anyway, and re-authoring with explicit lineage notes is cleaner.

## Related session

- ADR `plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md` amendments 2/3 lost: original SHAs `8ef6bad1` (amendment 2), `b6ff1224` (amendment 3); re-authored as `919a7149` (amendment 2) and bundled into `af788355` (amendment 3) on 2026-04-27.
