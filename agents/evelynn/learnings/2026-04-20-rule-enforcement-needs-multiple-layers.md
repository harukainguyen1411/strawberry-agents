# Rule enforcement needs multiple independent layers

**Date:** 2026-04-20
**Source:** Plan-path discipline — required 3 separate enforcement layers before it held reliably (CLAUDE.md universal rule, plan-promote.sh guard, shared rules in planner `_shared`)

## Observation

The plan-path discipline rule (plans live in the correct subdirectory for their lifecycle stage) existed in CLAUDE.md, but plans still landed in wrong paths. Adding the rule only to CLAUDE.md created a single layer with gaps. Adding it to plan-promote.sh caught promotion-time violations but not authoring-time. Adding it to shared planner rules closed the authoring gap. All three layers were needed before the violation class disappeared.

## Lesson

A rule enforced at only one layer has the gap surface of all other layers. High-stakes rules (path discipline, plan lifecycle, commit format) need enforcement at every surface where the violation can occur: documentation layer (CLAUDE.md), tooling layer (scripts with guards), and authoring layer (shared rules or templates). Any single layer alone has gaps.

## Generalization

When designing enforcement for a universal invariant: identify every surface where a violation could occur (author time, commit time, promotion time, review time). Build a check at each surface. The redundancy is intentional — the layers are not duplicates; they catch violations at different lifecycle stages.

| last_used: 2026-04-20 |
