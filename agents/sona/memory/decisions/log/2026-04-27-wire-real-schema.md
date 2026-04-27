---
decision_id: 2026-04-27-wire-real-schema
date: 2026-04-27
coordinator: sona
concern: work
axes: [scope-vs-debt, simplification, root-cause-vs-symptom]
question: After diagnosing that /v1/schema is a stub returning only 11 fields (TODO comment line 117 in demo-config-mgmt/main.py), causing the agent's mental model to mismatch the actual seeded config (100+ fields), how to fix?
options:
  a: Standalone Karma quick-lane patch — wire /v1/schema to read tools/demo-studio-schema/schema.yaml. Independent of ADR-4. Demo-visibly transformative.
  b: Roll into ADR-4 scope — coherent but bigger PR.
  c: Defer until ADR-4 lands.
coordinator_pick: a
coordinator_confidence: high
duong_pick: a
predict: a
match: true
concurred: false
---

## Context

Brainstorming pass surfaced the actual root cause of the agent's "save not
sticking" gaslight pattern: the schema endpoint is a stub.

**Evidence (file:line):**
- `tools/demo-config-mgmt/main.py:117`: `# TODO: implement — return the real
  schema.yaml content from Firestore or bundled file`
- `tools/demo-config-mgmt/main.py:114-157`: `MOCK_SCHEMA_YAML` only documents
  11 fields (brand, market, languages, shortcode, colors.{5}, logos.{2})
- `tools/demo-config-mgmt/main.py:187`: GET /v1/schema returns the stub
- Real schema lives at `tools/demo-studio-schema/schema.yaml` (524 lines,
  canonical), referenced by the TODO but never wired
- DEFAULT_SEED config has card, params, ipadDemo, journey, tokenUi populated;
  iframe renders all of them; OpenAPI spec at api/config-mgmt.yaml documents
  all of them — only /v1/schema endpoint is wrong

Agent fetches /v1/schema, gets 11 fields, sincerely believes that's the full
contract, writes a minimal config, then get_config returns 100+ fields and
agent concludes its write didn't take.

## Why this matters

This is the simplification Duong was asking for. Not "fewer tools" — "make
the schema endpoint actually return the schema." The fix is small in code
(point /v1/schema at the canonical schema.yaml), transformative in agent
behavior. Combined with ADR-4's dispatch-drop fix, the demo flow gets to
ship-ready in two small PRs rather than one big ADR.

This was also a learning about my (coordinator) failure mode: I was reasoning
about behavior surfaces (cache, framing, force-retry) without checking
whether inputs to those surfaces were sane. Schema endpoint stub invalidates
the prior diagnosis layer.
