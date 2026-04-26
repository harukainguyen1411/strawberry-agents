---
decision_id: 2026-04-26-qa-two-stage-three-blockers
date: 2026-04-26
coordinator: evelynn
concern: personal
project: agent-network-v1
axes: [enforcement-strength, scope-of-trigger, doc-locality]
question: Three blocking decisions on qa-two-stage-architecture before Orianna promotion (D2 citation-tagging, D3 inferred-FAIL re-dispatch, D4 Rule 16 wording).
options:
  D2_a: accept as prompt-rule + PR-lint enforcement
  D2_b: accept as prompt-rule only (no CI gate)
  D2_c: reject — keep free-form
  D3_a: accept — re-verify loop on every inferred-FAIL
  D3_b: accept but only when requires_diagnosis=true
  D3_c: reject — over-engineered
  D4_a: amend Rule 16 inline with full contract
  D4_b: keep Rule 16 as-is, contract in akali.md + qa-pipeline.md, Rule 16 just references
  D4_c: defer to v2 plan
coordinator_pick: 1a 2a 3b
coordinator_confidence: medium
duong_pick: 1b 2b 3b
predict: 1a 2a 3b
match: false
concurred: false
---

## Context

After Aphelios Leg 4 audit surfaced qa-two-stage-architecture as not-yet-promotable, three blocking decisions presented in a/b/c form. Karma v1 (akali-qa-discipline-hooks) treated as separate yes/no — silence concurs with Pick: yes, high confidence.

## Why this matters

Pattern: Duong consistently picks lighter-touch enforcement (b) over invariant-strength (a) on this axis. D2 (lint-vs-prompt-only) and D3 (broad-vs-narrow trigger) both went b — favoring agent discipline over CI gates. D4 was 3b match — locality of contract in domain docs (akali.md/qa-pipeline.md) over universal rules (CLAUDE.md). Useful axis signal: enforcement-strength prefers prompt-rule with narrower triggers; doc-locality prefers domain over universal.
