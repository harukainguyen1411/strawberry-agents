---
decision_id: 2026-04-27-adr-1-tx-unit-test-harness
date: 2026-04-27
coordinator: sona
concern: work
axes: [test-framework-choice, layer-of-test-truth, drift-risk]
question: TX-unit-1..7 translator tests — JS-side (Node node --test) vs Python shim vs subprocess kludge
options:
  a: "Viktor adds Node node --test harness, rewrites TX-unit-* in JS, removes Rakan's Python translator file. Clean layer separation."
  b: "Python-side translator shim mirroring JS semantics; two implementations of one D2 contract (drift risk)."
  c: "Subprocess JS-from-Python wrapper; runtime kludge, slow tests."
coordinator_pick: a
coordinator_confidence: high
duong_pick: hands-off-autodecide
coordinator_autodecided: true
predict: same
match: true
concurred: false
---

## Context

Rakan committed 25 xfails on feat/adr-1-build-progress-bar @ 0451093. He authored TX-unit-1..7 ("pure-function D2 contract translator" tests) as Python xfails because no JS test harness exists in tools/demo-studio-v3/. But the translator (static/buildProgress.js) is browser JS — Python tests can't exercise it without a duplicate Python translator.

## Decision

a — Viktor authors static/__tests__/buildProgress.test.mjs using Node's built-in node --test (zero new deps), covers the same TX-unit-1..7 cases xfail-tagged, and removes tests/.../test_build_progress_translator.py. Two-commit shape on Viktor's branch satisfies Rule 12 for the JS unit tests:

1. chore(adr-1): replace python translator xfails with node --test xfails (xfail-only, removes Python file, adds JS file)
2. feat(adr-1): build-status BFF endpoint + SSE subscriber + progress UI + translator impl

Rakan's other 18 tests (T1 endpoint Python, integration, fault, seam) stay as-is — they correctly target Python or e2e layers.

## Why this matters

The translator is the contract heart of D2 (BuildProgress shape from raw factory events). Drift between JS impl and Python "spec" tests would silently mask bugs. Tests-in-impl-language is the boring-and-correct shape. node --test was picked over jest because it adds zero dependencies and the harness need is minimal (~7 pure-function cases).
