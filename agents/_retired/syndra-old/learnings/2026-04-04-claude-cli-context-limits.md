# Claude CLI — No Programmatic Context Exposure

**Finding:** Claude CLI does not expose context window usage, token counts, or session size programmatically. No `--get-context-size` flag, no MCP resource, no API endpoint. `/cost` works interactively inside a session but its output isn't machine-parseable from outside.

**Implication:** Any "how heavy is this agent?" monitoring must rely on self-reporting. The most reliable signal is compression events — when the system auto-compresses conversation history, the agent receives a system message and knows its context was full. Turn count and session duration are secondary proxies.

**Design consequence:** `report_context_health` tool (agent self-reports) + `get_agent_health_summary` tool (Evelynn queries all agents) is the correct architecture, not external observation.
