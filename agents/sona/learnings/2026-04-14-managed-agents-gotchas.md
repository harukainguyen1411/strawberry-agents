# Managed Agents API gotchas — 2026-04-14

Lessons from building Demo Studio v3 on Claude Managed Agents (SDK 0.94.1):

1. **Vault credentials use `display_name` not `name`**, and `static_bearer` auth requires `mcp_server_url` field
2. **`sessions.events.stream()` is NOT an async context manager** — it returns a coroutine that resolves to an async iterator. Use `stream = await client.beta.sessions.events.stream(id)`, not `async with`
3. **MCP toolset `permission_policy` defaults to `always_ask`** — every tool call blocks waiting for `user.tool_confirmation`. Set to `always_allow` for autonomous execution
4. **ngrok free tier interstitial blocks MCP connections** — the Managed Agent gets an HTML page instead of MCP response. Deploy to Cloud Run or use paid ngrok
5. **Google CDN caches Cloud Run 404s** — if a route returns 404 on initial failed deploy, the 404 is cached even after redeploying with the route. Use a different path (e.g. `/health` instead of `/healthz`)
6. **Agent discovers tools from MCP server at session creation** — removing a tool from the MCP server and restarting only affects NEW sessions, not existing ones
7. **`processed_at` is the timestamp field on events**, not `timestamp` — need to check via `model_fields` on the event class
8. **TDD catches integration bugs that unit tests miss** — ESM require crash, SSE API mismatch, frontend/backend contract mismatches were all invisible to mocked unit tests
