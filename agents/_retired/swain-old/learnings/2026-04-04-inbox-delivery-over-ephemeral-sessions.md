---
name: inbox-delivery-over-ephemeral-sessions
description: When bridging external messages (Telegram, Discord) to a running agent, prefer inbox delivery to the existing session over spawning new claude -p sessions
type: feedback
---

For bridging external channels to an agent, two approaches exist:

1. **Ephemeral session** — spawn `claude -p` per message with `--allowedTools` restricted to a safe subset
2. **Inbox delivery** — write an inbox file + notify the agent's existing iTerm session

**Prefer inbox delivery (v2)** for agents that run persistently:

- No cold-start latency (5-30s vs <1s)
- Agent retains full session context and memory
- Agent has access to all its MCP tools, not just a restricted subset
- Simpler bridge script — no claude CLI invocation, no error handling for claude failures
- Evelynn already runs persistently in iTerm; there's no reason to start a new session per message

**When ephemeral sessions make sense**: the agent doesn't run persistently, OR you want strict tool isolation for untrusted input (e.g., Discord public forum where prompt injection is a real risk).

**Why:** Telegram relay v1 used `claude -p` per message. v2 switched to inbox delivery, eliminating cold starts and context loss. Discord bridge still uses `claude --message` because it processes untrusted public input with a restricted toolset — appropriate there.
