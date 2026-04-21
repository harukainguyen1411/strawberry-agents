---
status: implemented
owner: syndra
---

# Turn-Based Multi-Agent Conversation System

## Problem

Current conversation system is append-only with no turn enforcement. Any agent can write at any time, agents re-read the full file each time, and there's no guarantee every participant gets to speak before the conversation moves on.

## Design

### File Format: `conversations/<slug>.turn.md`

```markdown
---
title: <slug>
mode: turn-based
participants: [evelynn, syndra, swain]
turn_order: [evelynn, syndra, swain]  # fixed rotation
current_turn: syndra                   # who speaks next
round: 2                               # increments when full rotation completes
created: 2026-04-03 22:30
---

## [1] Evelynn — 2026-04-03 22:30
First message that kicks off the conversation.

## [2] Syndra — 2026-04-03 22:31
My response.

## [3] Swain — 2026-04-03 22:32
My analysis.

## [4] Evelynn — 2026-04-03 22:33
Round 2 begins. Follow-up question.
```

### Primitives

**1. Turn cursor (frontmatter)**

- `current_turn` — the only agent allowed to append
- `round` — incremented after the last participant in `turn_order` speaks
- Each message gets a sequential `[N]` index

**2. Read cursor (per-agent, in frontmatter)**

```yaml
read_cursors:
  evelynn: 3
  syndra: 2
  swain: 3
```

Each agent records the last message index they've read. When it's their turn, they only read messages from `read_cursor + 1` to the latest `[N]`.

**3. Turn advancement**

After an agent appends their message:
1. Increment their `read_cursors` entry to the new message index
2. Set `current_turn` to the next agent in `turn_order`
3. If wrapping around to the first agent, increment `round`
4. Notify the next agent via `message_agent`

**4. Skip / pass**

An agent can post a `[PASS]` message to yield their turn without content:

```markdown
## [5] Swain — 2026-04-03 22:35 [PASS]
Nothing to add this round.
```

This still advances the turn.

**5. Conversation end**

Any agent can propose `[END]` in their message. The conversation closes when all remaining agents in the round either `[END]` or `[PASS]`.

### API (new agent-manager tools)

| Tool | Purpose |
|---|---|
| `start_turn_conversation(title, sender, participants, turn_order, message)` | Create a `.turn.md` file with frontmatter, post first message, notify next agent |
| `speak_in_turn(title, sender, message)` | Append message if it's sender's turn. Reject otherwise. Advance turn. Notify next. |
| `pass_turn(title, sender, reason?)` | Post a PASS message, advance turn |
| `end_turn_conversation(title, sender)` | Propose END, advance turn |
| `read_new_messages(title, agent)` | Return only messages after agent's read cursor, update cursor |
| `get_turn_status(title)` | Return current_turn, round, read_cursors |

### Enforcement Rules

1. **`speak_in_turn` rejects writes from non-current agents.** This is the core constraint. No exceptions.
2. **Notification is mandatory.** After every turn advance, the next agent gets an inbox message: `[inbox] It's your turn in conversation '<title>' (round N)`.
3. **Timeout (optional, future).** If an agent doesn't respond within X minutes, auto-PASS and move on. Not needed for v1.
4. **Read before write.** `speak_in_turn` internally calls `read_new_messages` first, so the speaking agent always sees everything before responding.

### How It Differs From Current System

| Current | Turn-based |
|---|---|
| Anyone appends anytime | Strict turn order enforced |
| Agent reads full file each time | Read cursor — only new messages |
| No guarantee all agents speak | Every agent gets a turn per round |
| No round concept | Explicit rounds with wrap-around |
| `.md` extension | `.turn.md` extension (coexists) |

### Implementation Path

1. Add frontmatter schema to agent-manager for `.turn.md` files
2. Implement `speak_in_turn` with turn validation + cursor management
3. Implement `read_new_messages` with cursor tracking
4. Add inbox notification on turn advance
5. Add `pass_turn` and `end_turn_conversation`
6. Update `agent-network.md` protocol docs

### V2 Additions

**6. Non-participant starter**

An agent can start a conversation without being in `turn_order`. The `sender` posts the opening message but is not part of the rotation.

- `start_turn_conversation` already takes `sender`, `participants`, and `turn_order` separately
- Change: `sender` does NOT need to be in `turn_order` or `participants`
- The starter's message gets index `[1]` as before
- `current_turn` is set to `turn_order[0]` (first rotating participant)
- Starter gets a read cursor so they can observe via `read_new_messages`, but never gets a turn
- Starter appears in frontmatter as `started_by: evelynn` (new field), separate from `turn_order`

Example frontmatter:
```yaml
started_by: evelynn
participants: [syndra, bard, ornn]
turn_order: [syndra, bard, ornn]
current_turn: syndra
```

**7. ESCALATE mechanic**

Any agent can escalate during their turn. This is a special message type that pauses the conversation and notifies Evelynn.

- New tool: `escalate_conversation(title, sender, reason)` — can only be called by `current_turn`
- Posts `## [N] Sender — timestamp [ESCALATE]` with the reason as body
- Sets `status: escalated` in frontmatter (new field, normally `active`)
- Sends inbox notification to Evelynn: `[ESCALATE] Conversation '<title>' escalated by <sender>. Reason: <reason>`
- While `status: escalated`, `speak_in_turn` rejects all writes (conversation is paused)
- New tool: `resolve_escalation(title, sender, resolution, action)` where action is `resume` or `escalate_to_duong`
  - `resume`: sets status back to `active`, posts resolution message, turn continues from where it paused
  - `escalate_to_duong`: keeps status `escalated`, sends Duong a notification (mechanism TBD — could be a special inbox or terminal alert)

Two-tier escalation path: **Agent → Evelynn → Duong**

**8. Protocol: decentralized conversation starts**

Update `agent-network.md` to encourage agents to start conversations with each other directly:
- Agents CAN use `start_turn_conversation` themselves — they don't need Evelynn to start every conversation
- Evelynn delegates and coordinates, but peer-to-peer is encouraged for technical discussions
- Only escalate to Evelynn on blockers, cross-domain conflicts, or when Duong's input is needed
- Evelynn can still observe any conversation via `read_new_messages`

### Updated API

| Tool | Purpose |
|---|---|
| `start_turn_conversation(title, sender, participants, turn_order, message)` | Create conversation. Sender need not be in turn_order (v2). |
| `speak_in_turn(title, sender, message)` | Post if it's your turn. Rejects if not, or if status is escalated. |
| `pass_turn(title, sender, reason?)` | Yield turn. |
| `end_turn_conversation(title, sender)` | Propose END. |
| `read_new_messages(title, agent)` | Read new messages since cursor. |
| `get_turn_status(title)` | Current turn, round, cursors, status. |
| `escalate_conversation(title, sender, reason)` | **New.** Pause conversation, notify Evelynn. |
| `resolve_escalation(title, sender, resolution, action)` | **New.** Resume or escalate to Duong. |

### Edge Cases

- **Agent not running**: Notification goes to inbox. When agent starts, they check inbox and find pending turns.
- **Agent crashes mid-turn**: Turn stays on them. Another agent or Duong can manually advance via `pass_turn`.
- **Late joiner**: Supported via `invite_to_conversation` (see V3 below).
- **Reordering**: `turn_order` is fixed at creation. Could add a `reorder_turns` tool later.
- **Escalation while not your turn**: `escalate_conversation` only works for `current_turn`. If a non-current agent needs to escalate, they must wait or use `message_agent` to Evelynn directly.
- **Nested escalation**: If Evelynn escalates to Duong and Duong resolves, Evelynn calls `resolve_escalation` with `resume` to unpause.
- **Non-participant observer**: The starter can `read_new_messages` but cannot `speak_in_turn` (not in turn_order).

### V3 Addition: Late Joiner (Invite Mid-Conversation)

**9. invite_to_conversation**

Any current participant (in `turn_order`) can invite a new agent into an active conversation.

- New tool: `invite_to_conversation(title, sender, agent, position?)`
  - `sender` must be in `turn_order` (current participants only)
  - `agent` is the new agent to add
  - `position` (optional): index in `turn_order` to insert at. Default: append to end.
  - Can be called at any time — does NOT require it to be sender's turn

**Behavior on invite:**

1. Add `agent` to `participants` and `turn_order` (at `position` or end)
2. Set `read_cursors[agent] = 0` — cursor at 0 means "read everything from the start"
3. Post a system message: `## [N] System — timestamp [JOIN] <agent> invited by <sender>`
4. Send inbox notification to the new agent: `You've been invited to conversation '<title>'. Use read_new_messages(title=<title>, agent=<agent>) to read the full history, then wait for your turn.`
5. Do NOT change `current_turn` — the current speaker's turn is not interrupted

**First read for the new agent:**

- `read_new_messages` with cursor at 0 returns the FULL conversation history (all messages from `[1]` to latest)
- After reading, cursor advances to latest — from this point on, reads are incremental like any other participant

**Turn order integration:**

- The new agent enters the rotation at their inserted position
- They get their first turn when the rotation naturally reaches them
- If inserted before `current_turn` in the order, they'll speak in the current round. If after, they speak when rotation wraps.

**Constraints:**

- Cannot invite an agent who is already in `turn_order`
- Cannot invite into an `ended` or `escalated` conversation
- The `started_by` agent (non-participant observer) cannot invite — only rotating participants can

### Updated API (V3)

| Tool | Purpose |
|---|---|
| `invite_to_conversation(title, sender, agent, position?)` | **New.** Add agent mid-conversation. Full history on first read, then incremental. |
