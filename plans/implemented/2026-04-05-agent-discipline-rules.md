---

## title: Agent Discipline Rules — Plan Approval Gate & Session Persistence  
status: approved  
owner: syndra  
date: 2026-04-05

# Agent Discipline Rules

Two behavioral problems observed on 2026-04-05 (Bard incident). Both are systemic — the rules exist implicitly but aren't enforced structurally.

## Problem 1: Agents Self-Approving Plans

**What happened:** Bard wrote a plan and implemented it in the same session without waiting for Duong's approval.

**The rule:** Plans flow through a gate: `proposed/` → Duong moves to `approved/` → Evelynn delegates execution. The author of a plan must never implement it themselves in the same session.

### Enforcement

**A. CLAUDE.md — add Critical Rule #7:**

```
7. **Never implement your own plan without approval** — Write plans to `plans/proposed/`. Stop. Only Evelynn delegates implementation after Duong moves the plan to `plans/approved/`. The plan author does not implement unless explicitly assigned.
```

**B. agent-network.md — add to Protocol section:**

```
9. **Plan approval gate:** After writing a plan to `plans/proposed/`, your task is done. Call `complete_task` and report to Evelynn. Do NOT proceed to implementation. Duong approves plans by moving them to `plans/approved/`. Evelynn then delegates execution (possibly to a different agent).
```

**C. No tooling changes needed.** The `plans/` directory structure already encodes the gate (`proposed/` → `approved/`). The problem is behavioral, not structural. The fix is making the rule explicit and unmissable.

## Problem 2: Agents Ending Sessions After Task Completion

**What happened:** Bard closed his session immediately after finishing a task, without waiting for further instructions.

**The rule:** Task completion ≠ session end. After completing a task, agents must stay open and wait. Only close when Duong explicitly says to end the session.

### Enforcement

**A. CLAUDE.md — add Critical Rule #8:**

```
8. **Never end your session after completing a task** — Complete the task, report to Evelynn, then wait for further instructions. Only close your session when Duong or Evelynn explicitly tells you to.
```

**B. agent-network.md — modify Session Closing Protocol preamble:**

Add before the numbered steps:

```
**When to close:** Only when Duong or Evelynn explicitly says to end your session (e.g., "end session", "shut down", "close"). Completing a task is NOT a trigger to close. After task completion, stay open and wait.
```

**C. No tooling changes needed.** The `log_session` tool already exists for closing — the problem is agents calling it prematurely. Making the trigger condition explicit ("Duong says so") is sufficient.

## Summary of Changes


| File                             | Change                                                          |
| -------------------------------- | --------------------------------------------------------------- |
| `CLAUDE.md`                      | Add critical rules #7 and #8                                    |
| `agents/memory/agent-network.md` | Add protocol rule #9 (plan gate), add closing trigger condition |


## Why No Tooling Changes

Both problems are instruction-following failures, not tool gaps. Adding guardrails in tooling (e.g., blocking `log_session` unless a flag is set) would add complexity without solving the root cause — agents need to read and follow the rules. The fix is making the rules impossible to miss by placing them in Critical Rules (the first thing every agent reads).

## Risk

Low. These are additive rule clarifications. No existing behavior changes for agents already following the implicit rules.