---
date: 2026-04-22
time: "09:00"
author: sona
concern: work
category: coordinator-discipline
severity: medium
friction_cost_minutes: 10
related_plan:
related_pr:
related_commit:
related_feedback: []
state: open
---

# Coordinator verify QA claims

## What went wrong

Sona accepted a QA completion claim from a subagent without independently verifying the claim against the actual Playwright report. The claim was partially incorrect; a visual regression was missed, discovered only when Lucian reviewed the PR.

## Suggestion

- (A) Coordinators must spot-check at least one non-trivial QA assertion per subagent QA report before accepting. Effort: S. Owner: Evelynn/Sona protocol.
- (B) Require subagents to include a screenshot hash or artifact path in QA claims so coordinators can fast-verify without a full re-run. Effort: M. Owner: Akali.

## Why I'm writing this now

Trigger #6 (coordinator-discipline slip) fired: independent verification of a QA claim was skipped, allowing a regression to reach review.
