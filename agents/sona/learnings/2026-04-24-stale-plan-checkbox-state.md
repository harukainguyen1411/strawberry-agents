# Learning: Stale plan checkbox state in open-threads.md

**Date:** 2026-04-24
**Session:** 576ce828-0eb2-457e-86ac-2864607e9f22 (shard 4df78d45)
**Concern:** work

## What happened

Two completed tasks were discovered to still show as open in `open-threads.md` during this session:

1. **T.P1.13b** — "Demo ready" panel implementation. Lulu was dispatched for a brief on this task. Soraka returned to surface the stale checkbox: T.P1.13b was already merged via PR #83 on 2026-04-23. Lulu's brief was redundant.

2. **T1/T3/T4 of preview-iframe-staleness-triage** — All three tasks were committed together in PR #67 (`ccd7a32`). Rakan verified that all 4 test invariants pass locally. The open-threads entry still showed these as pending dispatch items.

In both cases, a subagent was dispatched or work was planned based on open-threads state that didn't reflect merged reality.

## Root cause

Lissandra consolidations capture `open-threads.md` state at compact boundaries but do not reconcile against git merge history. When Lissandra writes a shard, she captures what was open _at that moment_. If a task completes between compacts, the checkbox stays open until a future Lissandra run or manual close catches it. The open-threads file is hand-maintained — there is no automated sync between PR merge events and open-thread checkbox state.

## Impact

- Wasted Lulu dispatch on redundant task brief.
- Risk of duplicate T1/T3/T4 implementation if the stale state had driven a Wave B dispatch before verification.

## Standing rule: audit before dispatch

Before dispatching Wave B, Wave C, or any task with a checkbox in the RUNWAY section of open-threads:

1. Run `git log --oneline feat/demo-studio-v3 | head -40` and scan for relevant PR merge commits.
2. Cross-check each "pending" item against the actual git history.
3. Close stale checkboxes before dispatching. Trust git log over open-threads for "done" status.

## Audit pattern for future sessions

When resuming a session with a task queue, allocate 2–3 minutes at the top of the session to run:
- `git log --oneline feat/demo-studio-v3 | head -50` — verify RUNWAY completion state
- `gh pr list --state merged --repo missmp/company-os | head -20` — check for PRs merged since last shard

Apply discovered completions to open-threads before acting.

---

## Occurrence 4 — 2026-04-24 (shard ec53a0d6)

Viktor returned from the Wave B T3+T4 dispatch and found both tasks already complete — committed in prior PRs. He updated PR #32 body with T3+T4 coverage rather than re-implementing. Wave B was fully done before the dispatch fired.

Pattern continues to recur at the same root cause: open-threads RUNWAY checkboxes are hand-maintained; consolidation doesn't reconcile against git merge history between compacts. Until an automated sync exists, the pre-dispatch audit rule above is mandatory. This is the third documented recurrence in session 576ce828.
