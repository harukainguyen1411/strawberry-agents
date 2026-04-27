---
decision_id: 2026-04-27-config-flow-fix-tracks
date: 2026-04-27
coordinator: sona
concern: work
axes: [scope-vs-debt, parallel-vs-serial, framework-adoption]
question: After confirming framing-fix root cause + asking about Agent SDK — which tracks to spin up?
options:
  a: Three parallel tracks — Azir authors ADR-4 (set_config tool_result framing fix); Karma authors small plan for `get_config_template` tool; Lux writes Agent SDK adoption assessment (advisory only, no ship-path)
  b: Bundle framing fix + template tool into single ADR-4; defer SDK assessment
  c: Pause and do full Agent SDK migration ADR before any further patches
coordinator_pick: a
coordinator_confidence: medium-high
duong_pick: a
predict: a
match: true
concurred: false
---

## Context

Two threads of investigation landed:
- **Thread B (Explore)**: Confirmed `_handle_set_config` returns
  `{"version": <int>, "validation": {..., "force_applied": true}}` with NO
  `is_error` flag on the validation-fail-then-force-retry path
  (tool_dispatch.py:283–296). LLM reads this as success; SSE side-channel
  emits `status: "config_saved"` reinforcing the framing.
- **Thread A (Ekko, still running)**: Cloud Run log scrape for the failing
  session — will tell us whether S2 actually persisted on force-write.

Duong dropped the actual agent payload showing structurally incomplete config
(missing `card.front[].value`, `card.back.fields[].value/section`,
`card.cta`). Two orthogonal fixes needed:
1. **Recovery path** — force-retry success must signal failure or carry
   unmissable warning text (ADR-class, contract change).
2. **Prevention path** — agent should clone a worked example, not invent the
   schema from priors. Cleanest shape: new `get_config_template(brand_hint?)`
   tool the agent calls before composing.

Duong asked about Agent SDK adoption. Honest answer: it provides Skills as a
first-class primitive but migration is non-trivial (rewrite agent loop, tool
registration, SSE bridging) and contradicts the "simple yet clean" project
DoD at this moment. Lux is the right author for the assessment — my
training-time knowledge of current SDK Skills/MCP maturity is partial.

## Why this matters

Three independent surfaces, three independent owners — no merge friction:
- Azir owns the ADR-4 contract change for tool_result framing
- Karma owns the small additive plan for the new template tool
- Lux owns advisory-only assessment of SDK adoption (no ship-path commitment)

(b) bundles unrelated review surfaces; (c) blocks ship-day for a multi-week
migration. (a) parallelizes cleanly and preserves the option to commit to SDK
later once Lux's assessment lands.
