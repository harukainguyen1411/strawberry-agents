# Verify outcome not intent when symbolic order is load-bearing

**Date:** 2026-04-20
**Source:** PR #6 post-merge fix (1dc9d26) — Talon's `zz-` prefix rename sorted after unit-tests instead of between secrets-guard and unit-tests

## Observation

The plan said "place the hook between secrets-guard and unit-tests." Talon matched the letter of the task (rename the file) but not the spirit (alphabetical sort order determines execution sequence). The `zz-` prefix sorts after `u` (unit-tests), not between `s` (secrets-guard) and `u`. The bug was invisible until the hook ordering was verified empirically.

## Lesson

When a task's correctness depends on an emergent property (alphabetical order, numeric sort, timestamp comparison, dependency graph topology), explicitly verify that the emergent property holds after the change — not just that the named action was performed. "I renamed the file" is not sufficient when the filename drives execution order.

## Generalization

Applies to any task where: file sort order drives execution, numeric IDs affect priority, dependency resolution is implicit, or the system's behavior derives from a property not stated in the change itself. The implementation intent and the runtime outcome are two different assertions. Verify both.

| last_used: 2026-04-20 |
