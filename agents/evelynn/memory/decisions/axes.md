# Axes — evelynn (personal)

Axis names are stable once added. Deprecation is additive: mark with
`deprecated: YYYY-MM-DD` in the header, do not delete.

## scope-vs-debt
  Added: 2026-04-25
  Definition: Cleanness / structural correctness (a) vs speed / incurred debt (b/c).
  When to tag: any decision that trades correctness, refactor scope, or long-term
  maintainability against delivery speed or accepted technical debt.

## explicit-vs-implicit
  Added: 2026-04-25
  Definition: Explicit declarations / ceremony (a) vs implicit / inferred defaults (b/c).
  When to tag: type annotations, config verbosity, convention-vs-configuration choices.

## hand-curated-vs-automated
  Added: 2026-04-25
  Definition: Human judgement and hand-written prose (a) vs automated / generated output (b/c).
  When to tag: content generation, summarisation, index maintenance, agent-written artefacts.

## rollout-phased-vs-single-cutover
  Added: 2026-04-25
  Definition: Incremental / gated rollout (a) vs single-shot cutover (b/c).
  When to tag: deployments, migrations, feature flags, breaking-change sequencing.
