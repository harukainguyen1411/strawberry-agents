# Viktor context ceiling on batched cross-phase impl

**Date:** 2026-04-21
**Reporter:** Sona
**Severity:** High — full dispatch lost, zero recoverable work visible to coordinator

## What happened

Viktor was dispatched (agent `a74a9bb7bcec58e5d`, Task #46) to implement MAL.B *and* MAD.B/C/F on the `company-os-integration` branch in one run. The prompt bundled:

1. Checkout + clean-tree verification on `company-os-integration`.
2. Merge `chore/mal-b-xfail` into integration, impl all MAL.B tasks against the ADR, flip xfails green per phase.
3. Survey for MAD.B/C/F xfail branches; merge + impl each phase if xfails present; skip + report if not.
4. Full pytest run on integration, excluding known-blocking `test_integration_l3.py`.
5. Claim-contract import sanity pass.
6. Report: commit SHAs, pytest summary tail, MAL.B task checklist, MAD B/C/F status.

Viktor terminated after **147 tool uses / 20 min 42 sec** with the single-line result `Prompt is too long`. No commit inventory, no pytest output, no progress checkpoint. The coordinator has to reconstruct state by inspecting the integration branch directly.

## Parallel contrast — Rakan succeeded at similar cost

Rakan (agent `a6c6582e96d23cf52`, Task #47) ran in parallel for **153 tool uses / 21 min 53 sec** — comparable budget — and returned a clean structured report with 3 branches created, 22 xfails authored across 5 test files, and explicit flags for tasks not translatable to xfails (MAD.F.2 ERRAND).

**Difference:** Rakan's scope was additive across three *independent* branches off workspace main. No integration-branch coherence to maintain; each MAD.{B,C,F} xfail branch was a fresh worktree with no cross-merge dependencies. Rakan could checkpoint progress branch-by-branch and a partial completion would still yield usable output (e.g. MAD.B branch landed even if MAD.F never started).

Viktor's scope was the opposite shape: a single mutable integration branch where every commit had to maintain coherence with the full merged tree, and where every phase (MAL.B → MAD.B → MAD.C → MAD.F) depended on the previous phase having merged cleanly. A partial Viktor is indistinguishable from a broken Viktor — the coordinator can't tell from "Prompt is too long" whether MAL.B landed, whether xfail flips committed, whether MAD.B got touched at all, or whether the integration branch is in a half-merged conflicted state.

## Root cause

**Complex-track builders batched across multiple phases on a single mutable branch exceed context budget because every phase compounds state: the merged tree grows, the impl surface grows, pytest output grows, hook chatter grows.** Rakan hit the same budget but got better work out of it because her branches didn't share state.

The prompt budget isn't the only problem — it's also *silent* failure. "Prompt is too long" is a hard termination; there's no chance for Viktor to run `git log --oneline` and report what landed before dying. No graceful-degradation checkpoint.

## Proposals

### 1. Split cross-phase impl into one-phase-per-dispatch for complex-track builders on mutable branches

Rule of thumb: if the builder's task involves merging external branches into a mutable integration branch AND implementing against multiple phases AND running tests, that's three multiplicative factors. Break on phase boundaries. The coordinator fan-out cost (N dispatches instead of 1) is cheaper than the recovery cost when a batched Viktor dies silently.

Concrete: what should have been one Viktor dispatch was actually four (MAL.B impl, MAD.B impl, MAD.C impl, MAD.F impl). Each one starts fresh, gets a focused report, and the coordinator can decide the next phase after verifying the last.

### 2. Mandatory progress checkpoint halfway through complex-track impl dispatches

Prompt addition: "After completing your first task group, write a one-line status summary to `agents/viktor/inbox/<task-id>-progress.md` naming the commits landed so far and what's next. This file becomes recoverable state if you hit context limits before finishing the full report."

Cheap, non-invasive, recovers some signal on silent termination. Sona's inbox-scan-on-startup convention already handles this class of file; no new infrastructure.

### 3. Distinguish phase-independent xfail authoring (Rakan-shape) from cumulative impl (Viktor-shape) in task routing

When Sona's breakdown produces a task like "implement phases X, Y, Z against branch B":
- If each phase lands on its own sibling branch (additive, independent) — safe to batch to one agent. Rakan-shape.
- If each phase mutates the same branch — split to N dispatches, one per phase. Viktor-shape.

This is already visible at the breakdown step; add it to Kayn/Aphelios's task template so downstream dispatches pick the right shape without the coordinator re-deriving it.

### 4. "Prompt is too long" termination should be one notch softer

Not Sona's to fix, but: the agent runtime's hard-kill on context-limit should at least save the last tool output buffer (pytest tail, git log) and pass it through as the result. Current behavior discards the entire run transcript — the coordinator sees `Prompt is too long` and nothing else. Partial output is vastly better than no output.

## Recommendation order

1. Ship #3 first — it's a breakdown-step text change in Kayn/Aphelios's template, zero infrastructure risk, prevents the recurrence pattern at the source.
2. Then #2 — prompt-template addition for complex-track builders touching mutable branches. Also cheap.
3. #1 is the coordinator-side behavior change that falls out of #3 naturally.
4. #4 is runtime/upstream; file it but don't wait for it.

## Today's cost

One Viktor dispatch lost. `company-os-integration` state unknown (coordinator-side checked post-termination and confirmed the integration branch exists in a worktree under `company-os-integration/`; the actual merge + impl state remains to be inspected). Re-dispatch of a fresh Viktor with MAL.B-only scope is the next step.
