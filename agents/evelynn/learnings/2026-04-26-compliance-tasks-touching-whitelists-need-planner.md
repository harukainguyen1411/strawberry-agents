---
date: 2026-04-26
agent: evelynn
session: 9c8170e8
concern: personal
related_pr: 91
related_tasks: [95, 111, 112]
tags: [routing, planner-bypass, compliance-shape-trap, opus-agents-staleness]
---

# Compliance-shaped tasks are still planner-shaped if they touch any whitelist, classifier, or rules table

## What happened

PR #87 (T8 mechanical sync, Viktor) merged with a Senna call-out: the lint
script `scripts/lint-subagent-rules.sh` reported 29 MISSING_BLOCK violations
across agent defs missing the canonical `<!-- include: -->` marker. I treated
this as reactive compliance — "just add the markers, no architectural
decisions" — and dispatched Talon directly via task #95 without a Karma
quick-lane plan.

Talon executed correctly against what the lint script declared. The lint
script's `OPUS_AGENTS=(...)` whitelist had **10 names**, but **17 agents
declare `model: opus`** in their frontmatter. The 7 missing names —
karma, xayah, sona, evelynn, lucian, senna, orianna — therefore got the
SONNET-EXECUTOR canonical block synced into their defs. That block contains
the literal bullet *"Sonnet executor: execute approved plans only — you
never design plans yourself"*, which is now living in the runtime prompt of
every planner, reviewer, coordinator, and the gatekeeper.

Lucian APPROVED on PR #91 (plan-fidelity: there was no plan, blocks were
extracted faithfully). Senna CHANGES_REQUESTED on PR #91 (code-correctness:
"Karma's prompt now tells her to never design plans"). Senna's catch
prevented a degraded-prompt regression from landing on main.

## What was supposed to happen

The coordinator-routing-check primitive at `_shared/coordinator-routing-check.md`
is explicit about exactly this failure mode:

> "When the dispatch feels obvious, that is the signal to run the block anyway,
>  not the signal to skip it."

The routing block on PR #91 dispatch should have surfaced two questions:

1. Is there a plan governing this work? (Answer: no — reactive cleanup.)
2. Should there be? (Answer: yes — *any task that touches a whitelist,
   classifier, allowlist, denylist, or rules table is planner-shaped*,
   because the planner's job is to ask "is this whitelist authoritative
   or stale?" before the executor takes it as authoritative.)

A Karma quick-lane plan would have included an explicit pre-flight step:
*"verify `OPUS_AGENTS` matches the set of `model: opus` agent defs."* Trivial
to author, trivial to execute, catches the gap pre-impl.

## Root cause

The trigger for "skip the planner" was the task's surface shape — *"add
missing markers, content is determined by an existing script."* That phrasing
is misleading. The script encodes a classification (which agent is which
tier); inlining content based on a stale classification produces wrong
content even when the inlining is mechanically correct. The compliance
shape is a disguise; the structural shape is *"derived data updated from
a possibly-stale source."*

Three classes of "compliance-feeling" tasks always need a planner pass:

1. **Whitelist / allowlist / denylist updates** — the list itself may be
   stale; the planner's job is to validate the list against ground truth.
2. **Mechanical sync from a classifier/rules table** — same shape; if
   the classifier is wrong, every output is wrong.
3. **"Just regenerate from spec" tasks** — if the spec is stale, the
   regeneration propagates the staleness everywhere.

The common pattern: any task where the executor takes a config / list /
spec as authoritative without an upstream planner asking "is the source
of truth still the source of truth?"

## Cost

Caught at PR #91 review by Senna. No production impact. Cost: one re-fix
cycle on Talon (task #112, Option A narrow), plus a queued follow-up Karma
plan (task #111, Option B structural) to introduce role-specific shared
blocks. Real cost was small.

The latent cost — what didn't happen because Senna caught it — is what
matters. If PR #91 had merged, every planner / reviewer / coordinator
session would have read "you never design plans yourself" in their system
prompt. That's a degraded-output regression spread across 7 critical agents,
hard to attribute, and easy to mis-blame on model variance.

## Discipline correction

Add to coordinator decision protocol: when about to dispatch executor-only
on a task that *feels* like compliance, run the routing block AND apply
this filter before skipping the planner gate:

> Does the task touch a whitelist, allowlist, denylist, classifier table,
> rules file, or any "list of names with associated behavior"? If yes,
> route through Karma quick-lane regardless of how mechanical the
> downstream work feels. The planner's job is to validate the source-of-
> truth, which is the work the executor cannot do.

Filing this discipline correction here rather than amending the routing
include — the include's "obvious-dispatch is the signal to run the block"
already covers the abstract case; what was missing was the concrete
"compliance-shape is a disguise" reading. This learning is the concrete
example to point future-me at.

## References

- PR #91: https://github.com/harukainguyen1411/strawberry-agents/pull/91
- Senna's CHANGES_REQUESTED review (the catch): same PR, `strawberry-reviewers-2`
- Task #95: original Talon dispatch (the bypass)
- Task #111: queued Option B Karma plan (role-specific shared blocks)
- Task #112: in-flight Option A narrow fix (extend OPUS_AGENTS + regression test)
- `_shared/coordinator-routing-check.md`: the primitive that caught this in retrospect
