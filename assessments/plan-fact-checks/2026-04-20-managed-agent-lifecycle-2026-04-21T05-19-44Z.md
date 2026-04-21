---
plan: plans/approved/work/2026-04-20-managed-agent-lifecycle.md
checked_at: 2026-04-21T05:19:44Z
auditor: orianna
check_version: 2
gate: task-gate-check
claude_cli: present
block_findings: 3
warn_findings: 0
info_findings: 1
---

## Block findings

1. **Step B — estimate_minutes (B3 alternative units):** alternative time unit literal `hours` found in Tasks section ("Budget: 2 hours." on the MAL.0.1 task line); AI-minutes (`estimate_minutes:`) is the only accepted unit per §D4. | **Severity:** block
2. **Step C — Test tasks:** no task under `## Tasks` carries `kind: test` metadata nor has a title matching `^(write|add|create|update) .* test` (case-insensitive); at least one qualifying test task is required when `tests_required: true` (§D2.2). Task titles like "xfail tests for ...", "Regression test for ...", and "Structured-log event assertions" do not satisfy the required regex. | **Severity:** block
3. **Step E — Sibling file:** sibling file `plans/approved/work/2026-04-20-managed-agent-lifecycle-tasks.md` must be removed; content must be inlined in the plan body under `## Tasks` (§D3 one-plan-one-file rule). The Tasks section in the ADR already inlines the decomposition; delete the sibling file. | **Severity:** block

## Warn findings

None.

## Info findings

1. **Step B — estimate_minutes (structural observation):** the `## Tasks` section defines tasks via `#### MAL.X.Y — …` H4 headings rather than `- [ ]` / `- [x]` checkbox entries, so the per-task B1/B2 literal checks did not trigger. However, not a single task in the section carries an `estimate_minutes:` field. This does not emit a block under the strict literal reading of §D4 B1 (which keys on checkbox-prefixed lines), but the intent of §D4 — one integer `estimate_minutes:` per task in [1,60] — is not being honoured. Recommendation: either reformat tasks as checkboxed entries with `estimate_minutes:` per entry, or revise the task-gate contract to cover H4-heading task lists. | **Severity:** info
