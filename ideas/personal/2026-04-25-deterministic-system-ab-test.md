---
slug: deterministic-system-ab-test
captured: 2026-04-25
captured_by: evelynn (relayed from Duong)
target_version: agent-network-v2
related_project: agent-network-v1
status: parked
---

# Idea: deterministic eval harness with A/A validation + A/B comparison for system improvement

## Terminology note (added 2026-04-25 after Duong follow-up)

Duong's instinct on "A/B testing" was partly right; the proper vocabulary has two phases:

- **A/A test** = the control-group / harness self-validation step. Run the baseline system N× on the same fixed input, expect identical results. If results vary, the harness itself is non-deterministic and can't be trusted yet. This is what "10/10 same setup, same result" actually names.
- **A/B test** = the actual baseline-vs-target comparison on the same fixed input. Compare distributions or deltas.

**Best single phrase for the whole pattern:**

> **Deterministic eval harness with A/A validation** (self-test) **then A/B comparison** (system-vs-system measurement).

**Field-specific synonyms** the v2 plan author should be aware of:

- **Eval harness** — LLM/AI world (Anthropic internal, OpenAI evals, MMLU, HumanEval all use this)
- **Regression benchmark suite** — performance engineering
- **Golden test** / **snapshot test** — when comparing exact output bytes
- **Differential testing** — comparing two implementations on the same inputs
- **Controlled experiment** — formal scientific term

The original verbatim directive is preserved below. Filename + frontmatter slug retained as `deterministic-system-ab-test` for citation continuity (the v1 reference shape Duong used) — internal terminology in the v2 plan should use the more precise A/A+A/B phrasing.

## Captured directive (Duong, 2026-04-25, verbatim)

> for the v2 of the system, I would perhaps want a AB test or whatever it's called. Basically we should have a deterministic test of the system, how well it performs given a specific isolated environment with a test framework. with this, the goal is to determine if the system itself is improving overtime when isolated, because there can be multiple factors that can contribute to the result, not the system itself (agent can learn and adapt overtime for example, then it's not the system is better but the agent got better) I'm not a scientist but this is well designed in this field where you have a control group, to test if the test itself is setup correctly. If yes then 10/10 time with the same setup/system and the same test, it would provide the same result. then we do the test with the target system, to see how well it performs in the same environment in accordance to the other system. This is to make sure we're going in the right direction and not fool ourselves with the outcomes

## Distilled shape

- **Goal:** measure whether the *system* (orchestration, routing, primitives, hooks, plan lifecycle, etc.) is genuinely improving over time, isolated from confounds like model drift, agent-learning, or favorable task-mix.
- **Method (paraphrased):** classical A/B with a **control group** baseline.
  1. Build a deterministic test harness — fixed inputs, fixed environment, fixed seed, fixed model snapshot.
  2. Establish the **control group**: run the harness 10× against a frozen "baseline" version of the system. If results are not identical 10/10, the harness itself is non-deterministic and must be fixed before any system comparison is valid.
  3. Once the harness passes self-test (10/10 same-result), run it against the **target system** (the version under evaluation).
  4. Compare distributions.
- **Discriminator:** if the target system performs better (or worse) under the same fixed environment, that delta is attributable to the *system* — not to the agent or model adapting.

## Why this matters (Duong's reasoning, distilled)

Multiple factors contribute to "the system feels better":
- the underlying LLM may have improved
- agent-learning (memory, learnings, prompt evolution) compounds
- task-mix may be drifting easier
- Duong himself may be giving better briefs

A deterministic harness with a control group **isolates the system contribution** and prevents fooling ourselves with surface-level outcomes.

## Open shape questions (for the v2 plan author)

- What's the harness substrate? (Recorded transcripts? Synthetic agent fixtures? Frozen model snapshots? Local LLM stubs?)
- What's the success metric? (Plan-quality scoring? Time-to-merge? Reviewer-rejection rate? Compound metric?)
- How is "the system" snapshotted for replay? (Git tag? Hashed bundle of agent defs + hooks + scripts + canonical-v1 lock?)
- Frequency: per major release? Continuous on a CI-like cadence?
- How is *agent-learning state* held constant across A and B runs? (Reset memory directory? Pin to a snapshot?)
- What's the "control group" comparison? (Same system A/A to validate determinism, then A/B against target?)

## Related work in the system

- **Retrospection dashboard** (`plans/in-progress/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md`) — currently does observability on real production runs; not isolated. This idea is the *isolated counterpart*.
- **Agent-feedback system** (Plan A G1 just landed in PR #63) — captures fact-shaped signals from coordinator decisions; could feed into A/B harness as one of the metrics.
- **Coordinator-decision-feedback** (Plan B just landed in PR #64) — match-rate against expected decisions; A/B candidate metric (does the system's match-rate improve under fixed inputs?).
- **Project-context doctrine** (just approved, `7f09ba31`) — projects can declare a `tests_required:` field; v2 system A/B tests would attach to the v2 project doc.

## Why parking, not promoting

This is a v2-scope idea. v1 (current canonical-v1 push to EOD Sunday) is focused on shipping the orchestration baseline, dashboard, and feedback loop. The deterministic-A/B harness is a **measurement infrastructure** layer that becomes valuable once v1 is stable enough that "is the system improving?" becomes the operative question.

Earliest sensible promote-to-plan window: post-canonical-v1 retro (next Saturday).

## Pointer to doctrine

- Plan-of-plans + parking lot ADR: `plans/approved/personal/2026-04-25-plan-of-plans-and-parking-lot.md`
- This file is parked under that ADR's `ideas/<concern>/` mechanism, awaiting the parking-lot implementation tasks (Aphelios breakdown phase B–E) to land.
