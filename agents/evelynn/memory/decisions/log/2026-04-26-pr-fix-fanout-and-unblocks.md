---
decision_id: 2026-04-26-pr-fix-fanout-and-unblocks
date: 2026-04-26
coordinator: evelynn
concern: personal
project: agent-network-v1
axes: [scope-vs-debt, explicit-vs-implicit]
question: How to dispatch fixes for Senna REQUEST_CHANGES on PRs #68/#69/#70/#71 + unblock #67 + upgrade #72.
options:
  a: Bundled — parallel Jayce x4 (one per PR), Duong adds Human-Verified to #67, Senna re-spawn for #72.
  b: Serial Jayce, sequential unblocks.
  c: Talon lane for fixes (rejected — these are normal-track, not quick-lane).
coordinator_pick: a (with Talon corrected to Jayce after Duong feedback)
coordinator_confidence: high
duong_pick: a
predict: a
match: true
concurred: false
---

## Context

Wave reconcile after 12-agent parallel review. 4 PRs need code fixes (Senna findings), 1 needs CI unblock (Human-Verified override), 1 needs review-state upgrade (Senna COMMENTED → APPROVE). Original picked Talon for fixes; Duong corrected to Jayce (normal-track lane for review-feedback fixes, not Talon quick-lane).

## Why this matters

Lane discipline: Talon is for trivial Karma plans. Senna findings on these PRs are real bugfix work in existing features — Jayce shape. Mis-lane risk: Talon plans are tier:quick which collapses planning ceremony; using it for fix-work skips the proper review of *what* needs fixing.
