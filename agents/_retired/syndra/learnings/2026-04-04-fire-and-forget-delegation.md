# Fire-and-Forget Delegation — Protocol Rules Don't Fix Missing Primitives

**Finding:** When agents fail to report back after completing tasks, the instinct is to add a protocol rule ("you must report back"). This doesn't work reliably. Protocol compliance requires agents to remember the rule and prioritize it — both failure modes.

**Root cause:** `message_agent` has no concept of a task. It's a notification channel, not a task tracker. There's nothing to mark complete, nothing to check, no accountability mechanism.

**Fix:** Add the primitive that's missing — a delegation ledger. `delegate_task` creates a tracked entry with an embedded completion instruction in the inbox message itself. `complete_task` closes the loop. `check_delegations` gives the delegator visibility.

**Principle:** When a behavior keeps failing despite protocol rules, look for the missing infrastructure, not the missing compliance.
