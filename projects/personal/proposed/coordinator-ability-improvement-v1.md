---
slug: coordinator-ability-improvement-v1
status: proposed
concern: personal
scope: [personal, work]
owner: duong
created: 2026-04-26
deadline: TBD
claude_budget: TBD
tools_budget: TBD
risk: TBD
user: duong-only
focus_on:
  - reduce coordinator cognitive load (memory + parallelism reasoning)
  - structured advice, not autonomy — coordinator stays in the loop
  - small local model layer; predictable cost; offline-capable
less_focus_on:
  - autonomous action by the advisor layer (advisory only, no tool calls)
  - cloud-hosted inference (prefer local-first)
related_plans: []
---

# Project: coordinator-ability-improvement-v1

## Goal

Improve the coordinator (Evelynn / Sona) on two specific axes by introducing a small,
purpose-trained local LLM layer that watches the live project/plan state and offers
structured advice the coordinator can reason against — without taking action itself.

The two target axes:

### Axis 1 — Task distribution

Reduce the coordinator's reliance on memory for "what's the live state of the
project, what's blocked on what, who's idle, what should run next." The advisor
ingests the current project doc, active plans, in-flight subagent tasks, and
recent commits, then surfaces a ranked next-action list with rationale. The
coordinator reads the list, accepts/rejects/amends, and dispatches.

### Axis 2 — Parallelism delegation

Detect when a task the coordinator is about to dispatch (or has just dispatched)
is too large or too coarse-grained, and would benefit from being broken down
and fanned out across multiple agents in parallel. The advisor flags candidate
tasks pre-dispatch with a recommended slicing — coordinator decides whether to
slice or proceed monolithic.

## Why

Two recurring failure modes in current coordinator sessions, evidenced across
2026-04-25 and 2026-04-26 sessions:

1. **Memory drift on long sessions.** The coordinator forgets which legs have
   parallel slots open, which subagents are idle, which PRs are awaiting a
   reviewer. Manifests as serial dispatch when parallel was available, or as
   missed re-dispatches after a reviewer returned. Cost: hours of underused
   parallelism.

2. **Under-sliced dispatches.** The coordinator pattern-matches a task as
   "single agent, ~30 min" when it's actually "3 disjoint files, 3 agents,
   ~10 min each." Symptom: long single-stream tasks that could have been three
   parallel streams. Detected in retrospect via dashboard but not in the moment.

A purpose-trained advisor layer would add a structural pause and a second
opinion at exactly the points where the failure modes show up. It is not a
replacement for the coordinator — it is a memory aid and a parallelism
detector that surfaces structured suggestions.

## DoD

A working advisor layer integrated with the coordinator session lifecycle such
that:

1. The coordinator can query the advisor on-demand (e.g. `/advise`) and receive
   a ranked next-action list with rationale referencing live state.
2. The advisor automatically flags pre-dispatch when a task description matches
   the "candidate for slicing" heuristic, with a recommended slicing.
3. Advisor inference runs locally on the user's machine (no cloud dependency
   for the hot path); model and weights are versioned and reproducible.
4. The advisor is trained on Strawberry's own corpus (plans, breakdowns,
   dispatch records, retro-dashboard outputs) such that its advice is grounded
   in the system's own conventions, not generic project-management heuristics.
5. The coordinator retains full authority — the advisor never invokes tools or
   dispatches subagents directly.

## Constraints

- **Local-first inference.** Cloud inference is acceptable for training and
  offline experimentation; the live advisory path must run locally.
- **Predictable cost.** No per-token billing on the live path. Training cost is
  one-shot and budgeted upfront.
- **Advisory only.** The advisor never executes tools, dispatches subagents,
  edits files, or commits. Output is text recommendations to the coordinator.
- **Versioned model artifacts.** Weights and prompts are treated as reviewed
  artifacts under the same plan-lifecycle rules as code (Orianna gate, dual
  review on retraining PRs).

## Focus

- Reduce cognitive load on the coordinator
- Structured advice with explicit rationale (not opaque suggestions)
- Trained specifically for this workload (not a general-purpose chatbot)
- Honest about uncertainty (advisor flags "low confidence" rather than
  guessing)

## Open questions (project-level — to resolve before plan authoring)

1. **Model size and provider.** Local 7B–13B class (e.g. Llama, Qwen, Mistral)
   vs smaller specialised model (3B class with heavy fine-tuning)? Trade-off:
   larger model = better reasoning, more RAM/latency; smaller model = faster
   on-device, harder to train well.
2. **Training data shape.** Synthetic decision traces from the existing dispatch
   records + retro-dashboard outputs? Or a smaller manually curated golden set?
   Or a hybrid?
3. **Integration surface.** New skill (`/advise`)? PreToolUse hook on `Agent`
   tool that runs the slicing detector? Or a SessionStart-fired sidecar that
   the coordinator queries via a local socket?
4. **Failure mode behavior.** When the advisor model is unavailable
   (e.g. during cold start, OOM), does the coordinator block, fall back to
   memory-only, or surface a degraded-mode warning?
5. **Privacy.** Training data includes the full Strawberry corpus — plans,
   memory shards, learnings, decision logs. Is this acceptable for a local
   model? (Likely yes since model never leaves the user's machine, but worth
   stating explicitly.)

## DoD axes that are NOT in scope for v1

- Autonomous action by the advisor.
- Multi-coordinator coordination (Evelynn ↔ Sona handoff advice).
- Adversarial robustness (advisor prompt-injection defenses).
- Cross-machine model sharing.

## Notes

This project sits adjacent to but does not replace:

- **Retrospection dashboard** (`projects/personal/active/agent-network-v1.md` Leg 2)
  — that is observational, after-the-fact. The advisor is in-the-loop, real-time.
- **Plan-of-plans + parking lot** (`plans/approved/personal/2026-04-25-plan-of-plans-and-parking-lot.md`)
  — that surfaces priority among queued plans. The advisor surfaces priority
  among in-flight tasks within an active plan.
- **Coordinator deliberation primitive**
  (`plans/approved/personal/2026-04-25-coordinator-deliberation-primitive.md`)
  — that is a prompt-side discipline gate. The advisor is a separate process
  with its own model and its own data view.

The shape of the advisor's recommendations should align with the existing
parallel_slice_candidate / Karma quick-lane / Aphelios breakdown vocabulary so
that its output is legible to the coordinator without translation.
