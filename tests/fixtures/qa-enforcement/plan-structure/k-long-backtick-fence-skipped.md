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

# Fixture K — §QA Plan heading inside 4-backtick fence is skipped (ACCEPT)

## Context

This fixture exercises the extended fenced-block skipper for longer fences
(4+ backticks). A `## QA Plan` heading inside a ```````` fence must not be
recognized as the real section. The real `## QA Plan` follows the fence.

## Decision

Shows 4-backtick fence skipping in the plan-structure linter.

````
## QA Plan
This is inside a 4-backtick fence — the linter must skip this.
````

## QA Plan

**UI involvement:** no

- Output: script exit code tested by fixture runner
- Verification: bash linter against this fixture exits 0
- Edge case covered: 4-backtick fences are not opened by a 3-backtick closer
- PR marker QA-Verification: long-fence fixture suite ran clean

## Tasks

- T1: Validate long-backtick fence handling
  owner: viktor
