---
slug: pre-dispatch-parallel-slice
date: 2026-04-25
owner: karma
concern: personal
status: proposed
complexity: quick
tier: quick
impl_set: [talon]
tests_required: false
orianna_gate_version: 2
related:
  - feedback/2026-04-25-pre-dispatch-parallel-slice-check.md
  - .claude/agents/_shared/coordinator-routing-check.md
  - architecture/agent-routing.md
---

# Pre-dispatch parallel-slice check

## Context

Duong flagged a coordinator failure mode: dispatching a single subagent on a task estimated to take hours when the work could be sliced into meaningful parallel streams. Two reasons: (1) subagent context windows are limited and quality degrades over long runs; (2) parallel streams speed execution multiplicatively. The decision rule is a 2-question gate: "Does the task take >30m? Can it be broken into meaningful parallel streams? If both yes, slice." Exception: long-but-simple wait-bound tasks (test runs, deploys) should not be sliced.

Responsibility splits across (a) breakdown agents (Aphelios, Kayn, Xayah, Caitlyn) — they classify each task at authoring time, and (b) coordinator critical thinking — Evelynn and Sona apply the gate before each dispatch using the breakdown agent's hint.

This plan encodes the doctrine into the coordinator routing primitive and the four breakdown-agent definitions before canonical-v1 lock. Time-estimation calibration (the bloated-estimate problem) is explicitly deferred to retrospection-dashboard prompt-quality v1.5; this plan only encodes the doctrine, not the measurement loop.

## Decision

1. Extend `.claude/agents/_shared/coordinator-routing-check.md` with a new "Slice-for-parallelism check" gate — a 2-question prompt block the coordinator runs before any dispatch flagged complex or estimated >30m.
2. Amend Aphelios, Kayn, Xayah, Caitlyn defs with a `## Slicing` step: when authoring task breakdowns, classify each task with `parallel_slice_candidate: yes | no | wait-bound`.
3. Task-breakdown YAML grows a `parallel_slice_candidate` field on each task entry. Default `no` if missing — fail-soft, not fail-loud, to avoid breaking in-flight flows pre-canonical-v1.
4. Defer time-estimation calibration to dashboard prompt-quality v1.5.

## Tasks

- **T1** — kind: doc-edit; estimate_minutes: 15; files: `.claude/agents/_shared/coordinator-routing-check.md`; detail: append a `## Slice-for-parallelism check` section after the existing routing block. Include the 2-question gate (>30m AND parallelizable), the wait-bound exception, and instruction to read the breakdown task's `parallel_slice_candidate` field as the hint. DoD: section present; gate questions verbatim; wait-bound exception called out; coordinator instructed to default to `no` when field absent.
- **T2** — kind: doc-edit; estimate_minutes: 20; files: `.claude/agents/aphelios.md`, `.claude/agents/kayn.md`; detail: add a `## Slicing` step instructing the agent to classify every task with `parallel_slice_candidate: yes | no | wait-bound` in the task frontmatter/inline YAML. Include the same 2-question rule and wait-bound definition. DoD: both files contain the Slicing step and the field-name spec.
- **T3** — kind: doc-edit; estimate_minutes: 20; files: `.claude/agents/xayah.md`, `.claude/agents/caitlyn.md`; detail: same shape as T2 — add `## Slicing` step with the classification field. DoD: both files contain the Slicing step.
- **T4** — kind: script-run; estimate_minutes: 5; files: (no edits — execution only); detail: run `scripts/sync-shared-rules.sh` to propagate the `_shared/coordinator-routing-check.md` change into any downstream agent defs that include it (Evelynn, Sona). DoD: script exits 0; `git status` shows propagated edits if any; commit them in the same change.
- **T5** — kind: smoke-test; estimate_minutes: 15; files: (none — verification only); detail: dispatch Aphelios or Kayn on a small known-multi-stream breakdown and verify the resulting plan's task entries include the `parallel_slice_candidate` field. DoD: at least one breakdown produced post-change shows the field populated on each task; no field absence regressions.

## Test plan

- **TT1** — coordinator-routing-check primitive contains the new gate. Read `.claude/agents/_shared/coordinator-routing-check.md`; assert the heading `## Slice-for-parallelism check` is present and contains both gate questions.
- **TT2** — agent-def round-trip. Sample one breakdown produced after T2/T3 land; assert each task entry contains a `parallel_slice_candidate` key with one of `yes | no | wait-bound`.

No xfail-first required: these are doc/prompt edits, not code changes in a TDD-enabled service (Rule 12 scope).

## Out of scope

- Time-estimation calibration loop and bloat measurement — deferred to retrospection-dashboard prompt-quality v1.5.
- Hard-blocking dispatches missing `parallel_slice_candidate` — soft-default `no` for backward compatibility.
- Retroactive slicing or reclassification of in-flight plans.
- Dashboard column changes to surface the field.

## References

- Source feedback: `feedback/2026-04-25-pre-dispatch-parallel-slice-check.md`
- Routing primitive: `.claude/agents/_shared/coordinator-routing-check.md`
- Agent routing matrix: `architecture/agent-routing.md`
