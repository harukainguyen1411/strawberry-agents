---
decision_id: 2026-04-27-set-config-persistence-investigate
date: 2026-04-27
coordinator: sona
concern: work
axes: [diagnosis-vs-action, scope-vs-debt]
question: How to proceed on prod gaslight bug that survived #129 (cache drop) — agent calls set_config(Aviva), then get_config returns Allianz?
options:
  a: Pure investigation (Explore agent) — pull session state from prod API, cross-check set_config/get_config tool-result envelopes, identify which of three scenarios (silent set_config failure / stale read store / per-turn reset)
  b: Investigation + Azir ADR in parallel — burn planner cycles before diagnosis lands
  c: Dispatch Azir directly — too early without diagnosis
coordinator_pick: a
coordinator_confidence: high
duong_pick: a
predict: a
match: true
concurred: false
---

## Context

PR #129 (`f313b927`) verifiably deployed at 100% traffic on prod (`/__build_info`
matches; revision `demo-studio-00041-5h8`). PR #129 dropped
`_vanilla_session_configs` and stripped `{config_block}`/`{initial_config}`
from SYSTEM_PROMPT — the cache path that previously caused the Allianz pin is
provably gone from the deployed image.

But Duong's manual test on session `e352044b37c04e828c7524c7034fdb75` shows the
same gaslight wording: agent calls `set_config(Aviva)` → "Config saved
successfully" → calls `get_config` to verify → comes back as Allianz → agent
concludes "my Aviva config didn't fully replace it" and retries.

This means the cache was not the only path producing the symptom. Three
scenarios on the table:
1. `set_config` returns 2xx but doesn't persist Aviva to session state
2. `get_config` reads from a stale or different store than `set_config` writes
3. Per-turn reset / race re-seeds Allianz between turns

## Why this matters

Cache fix taught us: assuming the failure mode without evidence costs a deploy
cycle. Diagnosis-first means the next fix targets the actual divergence point.
Azir authoring an ADR before the diagnosis would burn his cycles on the wrong
scenario; option (a) is a 10–20 min investigation that decides which planner
shape comes next. Option (b) parallelizes optimistically but pays double if
diagnosis surprises us.
