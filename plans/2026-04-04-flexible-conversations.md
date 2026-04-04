---
status: proposed
owner: syndra
---

# Flexible Turn-Based Conversations — Design Proposal

**Problem:** Strict turn order blocks agents from working while waiting. No dynamic participant addition mid-conversation (invite_to_conversation exists but was never battle-tested).

## Design: Hybrid Turn Model

Replace strict sequential turns with a **priority turn + open window** model. Two modes coexist:

### Mode 1: Ordered (current default, keep as-is)
Strict round-robin. Good for structured reviews, word chains, anything needing sequence. No changes needed.

### Mode 2: Flexible (new)
Key change: **any participant can speak at any time**, but there's still a "expected next" hint for coordination.

#### How it works

1. **`start_turn_conversation`** gains a new parameter: `mode: "ordered" | "flexible"` (default: `"ordered"` for backward compatibility)

2. In flexible mode:
   - `speak_in_turn` → renamed/aliased to `speak` — removes the "must be current_turn" check
   - `current_turn` becomes `suggested_next` — a hint, not a gate
   - Any participant can speak at any time
   - After each message, `suggested_next` rotates to the next agent who hasn't spoken this round (round-robin suggestion, not enforcement)
   - `pass_turn` still works — signals "I have nothing to add this round"
   - Round advances when all agents have spoken or passed

3. **Idle timeout hint:** If `suggested_next` hasn't spoken within N messages from others, they're assumed busy. The system doesn't block — others keep going.

#### Frontmatter changes

```yaml
mode: flexible          # new field
suggested_next: bard    # replaces current_turn semantically
spoken_this_round: [syndra, pyke]  # tracks who's contributed
```

#### Tool changes

| Tool | Ordered mode | Flexible mode |
|---|---|---|
| `speak_in_turn` | Enforces current_turn (unchanged) | Allows any participant; updates suggested_next |
| `pass_turn` | Enforces current_turn (unchanged) | Allows any participant |
| `end_turn_conversation` | Enforces current_turn (unchanged) | Allows any participant |
| `read_new_messages` | Unchanged | Unchanged |
| `get_turn_status` | Unchanged | Returns `suggested_next` + `spoken_this_round` |

### Dynamic Participant Addition (invite_to_conversation)

The existing implementation at line 1583 is actually solid. Issues to fix:

1. **Notification delivery** — The iTerm notification only fires if the agent window is already open. If the agent isn't running, the invite silently fails. Fix: also call `launch_agent` if the agent isn't in an active iTerm window.

2. **Flexible mode integration** — When invited in flexible mode, the new agent can speak immediately (no need to wait for their "turn"). In ordered mode, they slot into the turn_order at the specified position.

3. **Observer→participant upgrade** — The `started_by` observer should be able to invite themselves into the turn_order if they want to actively participate later. Currently blocked by the "already in participants" check (but not in turn_order). Fix: allow `invite_to_conversation` when agent is in participants but not in turn_order.

### Implementation Plan

**Phase 1 — Flexible mode core** (the big change):
- Add `mode` field to frontmatter
- Modify `speak_in_turn` to check mode before enforcing turn
- Add `spoken_this_round` tracking
- Round auto-advance when all have spoken/passed

**Phase 2 — invite_to_conversation fixes** (small):
- Auto-launch agent if not running
- Allow observer→participant upgrade
- Test with a real multi-agent scenario

**Phase 3 — Protocol docs update**:
- Update `agents/memory/agent-network.md` with flexible mode docs
- Add guidance on when to use ordered vs flexible

### What we're NOT doing

- No async message queues or pub/sub — overkill for our scale
- No concurrent write locking — file-based is fine for <15 agents
- No removing the ordered mode — it's still the right choice for structured work
- No webhook/polling system — inbox + iTerm notification is sufficient

### Migration

Zero breaking changes. `mode` defaults to `"ordered"`, all existing conversations continue to work. Flexible mode is opt-in per conversation.
