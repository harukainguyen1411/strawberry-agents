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

Sona accepted a QA completion claim from a subagent without independently verifying the claim against the actual Playwright report. In a single session, Akali's PASS summary was accepted on PR #66 (dashboard W2) and PR #67 (demo-preview port) without opening the QA report file or viewing a single screenshot. Both times Duong caught it with a direct "did you check the report / did you check the screenshot?" prompt. The pattern: coordinator sees only the subagent's closing narrative (interpretation), not the artifacts (ground truth). The narrative is secondhand; the screenshots are firsthand evidence. The claim was partially incorrect on verification; a visual regression was missed, discovered only when Lucian reviewed the PR.

## Suggestion

- (A) Coordinators must Read the QA report file (end-to-end) and ≥1 screenshot for each distinct surface before relaying "ready to merge". Effort: S. Owner: Evelynn/Sona protocol.
- (B) Require subagents to include a screenshot hash or artifact path in QA claims so coordinators can fast-verify without a full re-run. Effort: M. Owner: Akali.
- (C) Add a Rule 16-adjacent obligation to `agents/sona/CLAUDE.md` and `agents/evelynn/CLAUDE.md`: coordinator QA verification is mandatory before pronouncing a PR merge-ready. Effort: S. Owner: Evelynn.

## Why I'm writing this now

Trigger #6 (coordinator-discipline slip) fired: independent verification of a QA claim was skipped twice in one session, allowing a regression to reach review.
