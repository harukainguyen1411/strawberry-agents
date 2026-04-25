# Canonical-folder pinning beats file-SHA pinning when consolidation is in flight

## Context

Authored architecture-consolidation ADR alongside the cornerstone canonical-v1 plan. The cornerstone plan's deliverable is `architecture/canonical-v1.md` — a lock manifest pinning agent defs, hooks, invariants, and architecture docs. Initial cornerstone shape pinned individual file SHAs.

## Lesson

When you have two plans in flight where one consolidates a folder and the other locks the contents of that folder, the lock plan must pin **folder paths recursively**, not individual file SHAs. Otherwise:

- Every `git mv` from consolidation invalidates a lock pin, even though the content is unchanged.
- The lock plan becomes a moving target that has to be re-baselined every time the consolidation lands a wave.
- Worse: if the lock activates first, it blocks the consolidation entirely — every move triggers a `Lock-Bypass:` requirement.

The fix is sequencing + pin-shape:

1. **Consolidation lands first.** Folder structure stabilizes before lock baseline is computed.
2. **Lock pins folder paths recursively** — `architecture/agent-network-v1/` → hash of all member file SHAs combined. Adding/moving files within the folder updates the recursive hash atomically; the manifest line is one entry, not 21.
3. **File-level pins only for files with existential roles independent of folder location** — e.g. a hook reads `key-scripts.md` programmatically. None of our docs do today, so file-level pins are zero in practice.

## Generalization

Any structural change (move, rename, refactor) that lands during a freeze window must coordinate with the freeze mechanism on three axes: sequencing (which lands first), pin granularity (folder vs file), and bypass discipline (do we pre-emptively bypass during the change window or sequence to avoid bypass entirely). The third option — sequence to avoid bypass — is always preferable when achievable, because every used bypass is a precedent for future bypasses.

## Anchor

Plan: `plans/proposed/personal/2026-04-25-architecture-consolidation-v1.md` §8 "Interaction with the canonical-v1 lock manifest" + §9 wave plan + §11 R3 risk. Sister cornerstone: `plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md`.
