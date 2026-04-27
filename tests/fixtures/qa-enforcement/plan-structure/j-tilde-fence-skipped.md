---
status: proposed
project: agent-network-v1
concern: personal
owner: swain
created: 2026-04-27
last_reviewed: 2026-04-27
priority: P2
qa_plan: required
---

# Fixture J — §QA Plan heading inside tilde fence is skipped (ACCEPT)

## Context

This fixture exercises the extended fenced-block skipper: a `## QA Plan` heading
that appears inside a `~~~` tilde-fenced code block must NOT be recognized as the
real section. The real `## QA Plan` section follows the fence.

## Decision

Shows tilde-fence skipping in the plan-structure linter.

~~~
## QA Plan
This is inside a tilde fence — the linter must skip this.
~~~

## QA Plan

**UI involvement:** no

- Output: script exit code tested by fixture runner
- Verification: bash linter against this fixture exits 0
- Edge case covered: tilde-style fence blocks are not treated as headings
- PR marker QA-Verification: tilde-fence fixture suite ran clean

## Tasks

- T1: Validate tilde-fence handling
  owner: viktor
