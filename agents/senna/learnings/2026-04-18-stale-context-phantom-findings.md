---
date: 2026-04-18
topic: stale-context-phantom-findings
---

# Stale Context Produces Phantom Findings

Long-running Senna sessions can accumulate false beliefs about project state that survive contradicting evidence. In this session, a prior Senna instance persistently flagged `npm install` in unit-tests.yml as wrong, claiming dashboards uses pnpm — despite the diff showing plain `npm`, and despite being told the project is an npm workspace with `packageManager: npm@11.7.0`.

**Rule:** When a fresh session is spawned to re-review, treat `gh pr diff <n>` as ground truth. Never carry forward findings that aren't supported by quoted diff lines. If a prior session's finding cannot be grounded in a literal line from the current diff, it is a phantom — discard it.

**How to apply:** Before posting any finding, quote the exact offending line from `gh pr diff`. If you cannot quote it, don't post it.
