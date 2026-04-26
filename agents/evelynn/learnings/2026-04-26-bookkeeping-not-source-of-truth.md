# bookkeeping-not-source-of-truth

**Date:** 2026-04-26
**Session:** 9c8170e8 (project-mode, agent-network-v1)
**Trigger:** Two consecutive bookkeeping-trust failures in the same session, both corrected by Duong.

---

## What happened

**Failure 1 — Swain 20 OQs:** I surfaced the 20 Swain open questions as if they were blocking the unified-process synthesis. The synthesis ADR §7.5 had already recorded Duong skip-to-concurred all 20 with recommended-`a` defaults on 2026-04-25. The open-threads.md entry did not reflect this closure. I read the open-threads entry and acted on it as if it were current.

**Failure 2 — Lux monitoring OQs:** I surfaced the 6 Lux monitoring open questions as if they required Duong answers before Swain could proceed with the retrospection dashboard. The retrospection-dashboard plan §7 explicitly marked them "RESOLVED 2026-04-25" and recorded the Langfuse rejection for v1. The open-threads.md entry still showed them as outstanding.

Duong's correction: *"check the current state of the project, don't rely on the open thread. We should have the status quo as the source of truth, not what you remember to write down on a file."*

---

## The structural failure

`open-threads.md` and memory shards drift fast under heavy parallel implementation. In a session where multiple subagents are merging PRs and closing plan items simultaneously, the bookkeeping layer (open-threads, last-sessions shards) is **always behind** the artifact layer (plan files, PR state, `architecture/` docs, git log).

Presenting an open thread entry to Duong as a blocker without verifying the underlying artifact is a coordination error. It wastes Duong's attention on resolved issues and signals I am working from stale state.

---

## The rule

**Bookkeeping is downstream of artifacts, never upstream.**

Before surfacing any OQ, blocker, or outstanding item to Duong:

1. Verify against the actual plan file or ADR on disk — check the relevant section directly.
2. Check `gh pr list` and `gh pr view` for PR state, not remembered status.
3. Check `git log --oneline -10` for recent merges that might have closed the item.
4. Only if the artifact layer confirms the item is genuinely open, surface it.

The open-threads.md entry is an **index hint**, not a ground truth. Its value is navigation speed, not accuracy under churn.

---

## Corollaries

- Yuumi reconciliation (re-grounding open-threads.md against disk + gh) should run at the start of any project-mode session where parallel impl was active in the prior leg.
- When a session involves more than 3 simultaneous subagent streams, assume open-threads.md is at least one session behind.
- Skarner can verify artifact state quickly; dispatch before surfacing anything as blocking if there is any doubt.

---

**last_used:** 2026-04-26
