# Managed-agent architecture requires MCP by construction

**Date:** 2026-04-21
**Session:** ship-day fourth leg (shard 2026-04-21-4c6f055d)

## What happened

Duong asked "so we need a demo-studio backend AND an mcp server??" and "Why? why can't our BE be the mcp server??" after hitting a 503 on `demo-studio-mcp` Cloud Run. The question was reasonable — from the outside, two services look redundant. I presented three architecture options. Duong chose Option A (merge MCP into S1 in-process) initially, then also requested Option B (vanilla API) to compare.

## The lesson

When an architecture decision about MCP vs. vanilla API is on the table, frame the dependency clearly upfront:

- **MCP is load-bearing when the agent loop is autonomous** — the Anthropic SDK's managed agents consume tool definitions from MCP servers. If the agent needs to call service-specific tools (trigger_factory, get_schema, etc.) without a human approving each call, MCP is how those tools are registered and dispatched. Removing MCP means removing the agent's tool interface.

- **Vanilla Messages API is viable only when the loop is synchronous/user-in-loop** — client-side tools work when a human (or thin orchestration layer) handles the tool_use → tool_result cycle manually. If the product needs autonomous multi-turn agent runs without blocking on user input, vanilla API does not replace MCP.

- **The Option A vs B decision is architectural** — Option A keeps the managed agent and merges its MCP server in-process (reducing Cloud Run services from 2 to 1). Option B eliminates the managed agent entirely and re-implements the loop as synchronous. These are fundamentally different products, not just different plumbing.

## Protocol implication

Before recommending an MCP in-process merge (Option A), the right question to surface to Duong is: "Does this product require autonomous agent runs (no user approval of each tool call)? If yes, MCP is load-bearing — the merge reduces infra complexity but does not eliminate the dependency."

Do not let infra frustration (a 503) drive an architecture decision without framing the autonomy tradeoff explicitly.

## Cross-reference

- Open thread: `Architecture decision — MCP in-process (Option A) vs vanilla API (Option B)` in `open-threads.md`
- Competing plans: `plans/proposed/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md` (Option A) vs `plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md` (Option B)
