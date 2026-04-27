---
decision_id: 2026-04-27-set-config-validation-frame
date: 2026-04-27
coordinator: sona
concern: work
axes: [diagnosis-vs-action, parallel-vs-serial]
question: Sharpened diagnosis after seeing actual set_config payload — agent sent structurally incomplete config (missing card.front[].value, card.back.fields[].value/section, card.cta). Hypothesis: S2 validation rejects, handler force-retry path mis-frames the tool_result as success. Next move?
options:
  a: Pull S2 logs (Ekko) + audit tool_dispatch handler success-framing (Explore) in parallel
  b: All three (logs + handler audit + agent SYSTEM_PROMPT schema audit) in parallel
  c: Only handler audit — bug is almost certainly there
coordinator_pick: a
coordinator_confidence: high
duong_pick: a
predict: a
match: true
concurred: false
---

## Context

Duong dropped the actual `set_config` tool_use payload from session
e352044b37c04e828c7524c7034fdb75. Comparison to known-good Aviva config
(/tmp/aviva-config.json) reveals: agent sent payload missing
`card.front[].value`, `card.back.fields[].value`, `card.back.fields[].section`,
and `card.cta` entirely.

S2 (demo-config-mgmt) almost certainly rejects on validation. Handler in
tool_dispatch.py:223 retries with force=True on ValidationError. Two failure
paths:

1. Force-write rejected → handler returns is_error but tool_result text
   contains a version/success-shaped fragment that the agent narrates as
   "Config saved successfully".
2. Force-write accepted but stored as invalid → `GET /v1/config/{id}` returns
   the last valid config (Allianz seed).

Either way the handler's tool_result framing is the suspect surface — same
class of bug as PR #126 (422 swallowed), now showing on the success path
instead of the error path.

## Why this matters

Sharpened hypothesis demands targeted evidence. S2 logs (Ekko) deliver direct
ground truth — what S2 actually responded with for this session and which
retry branch fired. Handler audit (Explore) identifies the dispatch text
framing bug if it exists. Together they pin diagnosis without burning Azir
cycles. Option (b) adds an agent-prompt audit but that's downstream — if
handler errors are surfaced cleanly, the agent self-corrects from
tool_result. Option (c) skips the ground-truth check that prevented us from
guessing wrong on the cache fix.
