# Coordinator parallelism is now mandatory

**Date:** 2026-04-21
**Source:** Sixth-leg session; user-added rule during ship-day.

## What changed

Duong added a new mandatory rule: "Parallelism preference (mandatory for coordinators)." Coordinators must maximize parallelism when dispatching independent tasks. The prior restriction "never parallelize same agent" has been explicitly retired.

## Behavioral impact

- When multiple independent tasks exist, dispatch them in a single message as parallel Agent tool calls — even if they target the same agent type (e.g., two Viктор instances, two Xayah instances).
- The restriction that prevented same-agent parallelism was a conservative early default. It no longer applies.
- The criterion for parallelization is task independence, not agent identity.

## Exception

Sequential dispatch still applies when later tasks depend on results from earlier ones. State dependency, not agent identity, is the gating criterion.

## Example (this leg)

Xayah #2 (E2E test plan) and Heimerdinger (deploy checklist) were dispatched in parallel for the Azir ship-gate. Aphelios (Option B decomp) and Xayah (Option B test-plan) were dispatched in parallel. This is correct behavior under the new rule.

## Where this rule lives

`agents/memory/duong.md` §50 parallelism mandate. The rule is coordinator-wide, not session-specific.
