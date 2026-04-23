---
status: in-progress
complexity: complex
concern: work
owner: swain
created: 2026-04-21
tags:
  - demo-studio
  - vanilla-api
  - re-architecture
  - work
tests_required: true
---

# ADR: Demo Studio v3 — Vanilla Messages API Ship (Option B)

<!-- orianna: ok — all bare module and repo paths in this plan (company-os/tools/demo-studio-v3/, company-os/tools/demo-studio-mcp/, company-os/tools/demo-factory/, company-os/tools/demo-preview/, company-os/tools/demo-config-mgmt/, company-os/tools/demo-verifier/, agent_proxy.py, setup_agent.py, session_store.py, managed_session_client.py, main.py, managed_session_monitor.py, mcp_app.py, conversation_store.py, tool_dispatch.py, stream_translator.py, config_mgmt_client.py, factory_bridge.py, server.ts, session.html, static/session.js, deploy.sh, .env.example) reference files inside the missmp/company-os work workspace; this plan is architecture-only and creates no strawberry-agents files under those names -->
<!-- orianna: ok — every HTTP route token (/dashboard, /dashboard/managed-agents/*, /session/new, /session/{id}/chat, /session/{id}/stream, /session/{id}/build, /session/{id}/logs, /v1/config, /v1/config/{id}, /v1/preview/{id}, /build, /verify, /mcp) is an HTTP path on a Cloud Run service, not a filesystem path -->
<!-- orianna: ok — every Firestore collection path (demo-studio-sessions, demo-studio-sessions/{sessionId}/conversations/{seq}, demo-studio-sessions/{sessionId}/events/{seq}, demo-studio-system-prompt/current, demo-studio-tool-results/{session}/{seq}) is a Firestore/GCS object path, not filesystem -->
<!-- orianna: ok — env-var names (DEMO_STUDIO_MCP_URL, DEMO_STUDIO_MCP_TOKEN, MANAGED_AGENT_ID, MANAGED_ENVIRONMENT_ID, MANAGED_VAULT_ID, MANAGED_AGENT_DASHBOARD, MANAGED_SESSION_MONITOR_ENABLED, IDLE_WARN_MINUTES, IDLE_TERMINATE_MINUTES, SCAN_INTERVAL_SECONDS, ANTHROPIC_API_KEY, CLAUDE_MODEL, MAX_TOKENS, MAX_TURNS, SYSTEM_PROMPT) are environment variables or Python constants, not filesystem paths -->
<!-- orianna: ok — external URL host (api.anthropic.com) and SDK method names (client.beta.agents.create, client.messages.create, client.messages.stream, client.beta.sessions.delete) are external references, not files -->
<!-- orianna: ok — git branch tokens (integration/demo-studio-v3-waves-1-4, integration/demo-studio-v3-vanilla-api, integration/...) are branch names under missmp/company-os, not filesystem paths -->
<!-- plan-lifecycle tokens (proposed/, approved/, implemented/, archived/, plans/implemented/work/, plans/proposed/work/) are stems of the plans/<status>/<concern>/ tree under strawberry-agents, resolved relative to the repo root not the work-concern checkout --> <!-- orianna: ok -->
<!-- prospective filenames managed-agent-lifecycle-retirement.md and managed-agent-dashboard-retirement.md are author-proposed future ADR paths under plans/implemented/work/; they do not yet exist and will be created by the implementer of phase D --> <!-- orianna: ok -->
<!-- bare `.md` and `.env.example` tokens inside prose (e.g. "the MAL/MAD `.md` files") are extension refs, not concrete filesystem paths --> <!-- orianna: ok -->

## 1. Context

Demo Studio v3 currently uses Anthropic's **managed agent** execution model. On each session, S1 calls `client.beta.agents.create(..., mcp_servers=[{url: DEMO_STUDIO_MCP_URL, token: DEMO_STUDIO_MCP_TOKEN}])` to spin up a server-side agent instance that holds its own conversation state, decides when to call tools, talks to a separate MCP server for config writes, and is addressable via `managedSessionId` stored on each Firestore session doc.

This model solved three problems when it was picked:

1. **Built-in conversation persistence** — Anthropic holds the message history server-side; S1 only has to pass `session_id` on each turn.
2. **Tool execution via MCP protocol** — the managed agent automatically speaks MCP to any registered server; S1 did not have to route tool calls back to itself.
3. **Observability** — every turn and tool call shows up in Anthropic's console, no custom tracing needed.

It also introduced costs that have compounded:

- **Two new ADRs** exist only because of it: MAL (managed-agent-lifecycle — idle scanner, terminate-on-terminal hook, Slack relay for billing alarm) and MAD (managed-agent-dashboard-tab — `/dashboard` surface that reconciles Firestore with Anthropic's view). Both landed at `plans/implemented/work/2026-04-20-managed-agent-lifecycle.md` and `plans/implemented/work/2026-04-20-managed-agent-dashboard-tab.md`. <!-- orianna: ok -->
- **A separate Cloud Run service** (`demo-studio-mcp`, TypeScript) that is currently **503** — its container image was orphaned when its GCR project was deleted (per the snapshot referenced in Karma's plan `plans/proposed/work/2026-04-21-mcp-inprocess-merge.md`). While 503, the managed agent cannot write to S2. The entire flow is gated on an MCP service that can break independently of S1. <!-- orianna: ok -->
- **Three auth surfaces to keep in sync** — Anthropic vault (`MANAGED_VAULT_ID`), MCP bearer (`DEMO_STUDIO_MCP_TOKEN`), S1 operator cookie. `setup_agent.py --force` must rewrite the vault on every URL/token rotation. <!-- orianna: ok -->
- **Drift risk between Firestore and Anthropic** — documented at length in MAL §1: partial writes leave managed sessions running until Anthropic internally expires them, so we built idle-scan + terminal-hook machinery to counteract a problem the managed model itself introduced.

Duong's actual use case is **synchronous human-in-the-loop**: browser open, user chats, iterates, builds. No "agent works autonomously overnight" scenario exists or is planned. Every benefit of the managed model that matters (long-running autonomy, detached observability, fleet management) is paying for capability we do not use.

The alternative — vanilla **Messages API** with **client-side tool execution** — trades the managed-agent affordances for a radically smaller surface: one container, one auth, one source of truth for conversation state (our own Firestore), and no MCP service to orphan.

Azir's `plans/proposed/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md` proceeds on the opposite assumption — keep the managed agent, merge MCP in-process. That plan is legitimate and may be the right answer. This plan exists so Duong can compare. Both should live in `proposed/` until he picks one. <!-- orianna: ok -->

## 2. Decision

**Replace the Anthropic managed agent with vanilla `anthropic.messages.create` calls.** Tools are defined as JSON schemas in S1 and dispatched client-side, in-process, by a Python registry. The MCP service is retired entirely. Conversation state is held in Firestore under the existing session doc (as a subcollection). <!-- orianna: ok -->

Per user turn, S1 executes a **tool-use loop**:

1. Append the new user message to the conversation.
2. Call `anthropic.messages.create(model="claude-sonnet-4-6", messages=[...], tools=[...], system=SYSTEM_PROMPT, stream=True)`.
3. Stream assistant text deltas to the browser over SSE as they arrive.
4. On `stop_reason == "tool_use"`: extract each `tool_use` block, look up the handler in the dispatch registry, execute in-process against S2/S3/S4 clients, append `tool_result` blocks, loop back to step 2.
5. On `stop_reason == "end_turn"`: finalize the stream, persist the assistant message, return.

S1 becomes the agent runtime. No managed session IDs, no MCP server, no per-session Anthropic-side state.

Model: **`claude-sonnet-4-6`** is the current default for Demo Studio (already in use by the managed agent). Model selection stays in a single S1 constant; migration to newer models is a one-line change.

## 3. Architecture

### 3.1 Before (managed + MCP)

```
Browser ──SSE── S1 (demo-studio-v3)
                │
                ├── create_managed_session() ──► Anthropic Managed Agent
                │                                  │
                │                                  │  (server-side state,
                │                                  │   server-side loop)
                │                                  ▼
                │                              MCP server
                │                                  │
                │                            ┌─────┴─────┐
                │                            ▼           ▼
                │                          S2 (cfg)    S3-self-hop
                │                                        │
                │◄─────── stream events ─────────────────┘
                │
                ├── managed_session_monitor.py (idle scanner)
                ├── /dashboard (MAD — reconcile with Anthropic list)  <!-- orianna: ok -->
                └── Firestore: demo-studio-sessions/{id}
                        └── managedSessionId
```

Four external dependencies: Anthropic Messages API, Anthropic Agents API, Anthropic Vault API, MCP Cloud Run service. Any one failing breaks the session.

### 3.2 After (vanilla + in-process tools)

```
Browser ──SSE── S1 (demo-studio-v3)
                │
                ├── /session/{id}/chat  (user message in)
                ├── /session/{id}/stream (SSE text out)
                │
                ├── agent_proxy.run_turn()
                │     │
                │     ├── load conversation (Firestore subcollection)
                │     ├── anthropic.messages.stream(model, messages,
                │     │                              tools, system)
                │     │     ──► api.anthropic.com (Messages API only)
                │     │
                │     └── on tool_use blocks:
                │           tool_dispatch.dispatch(name, input)
                │               │
                │               ├── get_schema   ─► config_mgmt_client
                │               ├── get_config   ─► config_mgmt_client
                │               ├── set_config   ─► config_mgmt_client
                │               ├── trigger_factory ─► factory_bridge
                │               └── web_search    ─► built-in (Anthropic hosts)
                │
                └── Firestore:
                      demo-studio-sessions/{id}              ← session doc
                      demo-studio-sessions/{id}/conversations/{seq}  ← NEW
```

One external dependency: Anthropic Messages API. Conversation is ours. Tools are ours.

### 3.3 Conversation persistence model

Messages stored in a Firestore **subcollection** `demo-studio-sessions/{sessionId}/conversations/{seq}`, one document per message, with fields: <!-- orianna: ok -->

| field | type | note |
|---|---|---|
| `seq` | int | monotonic sequence starting at 0 |
| `role` | `"user" \| "assistant"` | standard Messages API role |
| `content` | `list[dict]` | the Messages API content array — text blocks, tool_use blocks, tool_result blocks |
| `createdAt` | timestamp | server time |
| `stopReason` | `str \| None` | assistant messages only |
| `usage` | `dict \| None` | input/output tokens per turn |

On each turn, S1 reads the subcollection ordered by `seq`, reconstitutes the Messages API `messages` array by mapping `(role, content)` pairs, appends the new user message, runs the loop, and writes back new assistant/user-tool-result messages with monotonic `seq` values. Ordering is guaranteed by the sequence field, not Firestore timestamps (avoid clock skew).

Rationale for subcollection over packed-blob: the session doc has a 1 MB Firestore size limit; a long conversation with large tool results (schema fetches, preview HTML) will exceed it. Subcollections have no aggregate size bound; each document has its own 1 MB limit (tool results that exceed that are truncated and persisted with a `truncatedRef` pointer — see Q3).

### 3.4 Tool-dispatch registry

A Python module `tool_dispatch.py` exports: <!-- orianna: ok -->

```python
# shape; not committed code
TOOLS: list[ToolDef] = [
    {"name": "get_schema", "description": ..., "input_schema": {...}},
    {"name": "get_config", "description": ..., "input_schema": {...}},
    {"name": "set_config", "description": ..., "input_schema": {...}},
    {"name": "trigger_factory", "description": ..., "input_schema": {...}},
    # Anthropic-hosted built-in:
    {"type": "web_search_20241022", "name": "web_search"},
]

HANDLERS: dict[str, Callable[[dict, SessionContext], Awaitable[dict]]] = {
    "get_schema": handle_get_schema,
    "get_config": handle_get_config,
    "set_config": handle_set_config,
    "trigger_factory": handle_trigger_factory,
    # web_search: no handler — Anthropic executes server-side and returns results
    # in the assistant message content; S1 just passes through.
}
```

`TOOLS` is the list sent to `messages.create`. `HANDLERS` is what S1 actually executes when a `tool_use` block with that name comes back. The built-in `web_search_20241022` has no entry in `HANDLERS` because Anthropic hosts it — S1 does not execute anything, it just streams the resulting content blocks through. <!-- orianna: ok -->

Handler signature: takes the tool input dict + a `SessionContext` (session ID, auth, request-scoped clients), returns a dict to be encoded as `tool_result.content`. Handlers reuse existing S1 modules: `config_mgmt_client.py` (already proxies to S2), `factory_bridge.py` (already proxies to S3). No new HTTP plumbing. <!-- orianna: ok -->

### 3.5 SSE stream adaptation

Current SSE endpoint `/session/{id}/stream` multiplexes events from the managed-agent session. In the vanilla world, it multiplexes events from the `messages.stream` context manager. Event shape changes from Anthropic's managed-agent event types to Anthropic's Messages API streaming delta types (`content_block_start`, `content_block_delta`, `content_block_stop`, `message_delta`, `message_stop`). <!-- orianna: ok -->

S1 translates internal delta events into a stable browser-facing shape (so the UI does not have to know which backend is on):

```
event: text_delta    data: {"text": "..."}
event: tool_use      data: {"name": "set_config", "input": {...}}
event: tool_result   data: {"name": "set_config", "output_summary": "..."}
event: turn_end      data: {"stop_reason": "end_turn", "usage": {...}}
event: error         data: {"code": "...", "message": "..."}
```

UI contract unchanged; only the server-side adapter rewrites.

## 4. What's deleted

The following files, env vars, and services are **removed entirely** (not flagged, not dormant):

| artifact | path | reason |
|---|---|---|
| MCP service | `company-os/tools/demo-studio-mcp/` entire repo directory | no tools go over MCP anymore; retired at end of phase D | <!-- orianna: ok -->
| `setup_agent.py` | `company-os/tools/demo-studio-v3/setup_agent.py` | no managed agent to configure | <!-- orianna: ok -->
| Managed session monitor | `managed_session_monitor.py` | no managed sessions to scan | <!-- orianna: ok -->
| Managed session client | `managed_session_client.py` | replaced by direct Messages API calls in `agent_proxy.py` | <!-- orianna: ok -->
| MAL idle scanner config | `IDLE_WARN_MINUTES`, `IDLE_TERMINATE_MINUTES`, `SCAN_INTERVAL_SECONDS`, `MANAGED_SESSION_MONITOR_ENABLED` | no monitor |
| MAL Slack relay hook | tied to monitor | no monitor to alarm |
| MAD dashboard tab | `/dashboard` Managed Agents tab routes + UI + enrichment + `MANAGED_AGENT_DASHBOARD` flag | no managed agents to list | <!-- orianna: ok -->
| MCP URL + token env | `DEMO_STUDIO_MCP_URL`, `DEMO_STUDIO_MCP_TOKEN` | no MCP server |
| Managed agent refs | `MANAGED_AGENT_ID`, `MANAGED_ENVIRONMENT_ID`, `MANAGED_VAULT_ID` | no managed agent |
| `managedSessionId` field | Firestore `demo-studio-sessions.*` | greenfield; no prod data to migrate |
| Terminal-transition hook (MAL §2.1) | inside `session_store.transition_status` | no managed session to stop |

Two Firestore fields added by MAL/MAD also fall out: `lastActivityAt` (existed for idle scan), `managedStatus`/`degradedFields` (MAD reconciliation). These vanish with the dashboard tab.

## 5. What's new

### 5.1 Conversation persistence

New Firestore subcollection `demo-studio-sessions/{id}/conversations/{seq}` (schema in §3.3). New module `conversation_store.py` with the single-boundary API: <!-- orianna: ok -->

```
ConversationStore.append(session_id, message) -> seq
ConversationStore.load(session_id) -> list[Message]
ConversationStore.load_since(session_id, seq) -> list[Message]   # for replay
ConversationStore.truncate_for_model(messages, max_tokens) -> list[Message]
```

Boundary invariant mirrors SE: nothing outside `conversation_store.py` reads or writes the subcollection directly. <!-- orianna: ok -->

### 5.2 Tool-dispatch registry

New module `tool_dispatch.py` exporting `TOOLS` (list) and `dispatch(name, input, context) -> dict`. Five tools: <!-- orianna: ok -->

1. `get_schema` — proxies to `config_mgmt_client.fetch_schema()`.
2. `get_config` — proxies to `config_mgmt_client.fetch_config(session_id)`.
3. `set_config` — proxies to `config_mgmt_client.patch_config(session_id, path, value)`.
4. `trigger_factory` — proxies to `factory_bridge.trigger_build(session_id)`.
5. `web_search` (type `web_search_20241022`) — Anthropic-hosted; no handler.

Error mapping (NotFound / Unauthorized / ServiceUnavailable → user-facing strings) mirrors the TS MCP `server.ts` strings so the agent's learned responses stay stable. <!-- orianna: ok -->

### 5.3 Agent proxy rewrite

`agent_proxy.py` becomes a thin wrapper: <!-- orianna: ok -->

```
async def run_turn(session_id, user_text, sse_sink) -> None:
    messages = conversation_store.load(session_id)
    messages.append({"role": "user", "content": [{"type": "text", "text": user_text}]})
    while True:
        async with client.messages.stream(
            model=CLAUDE_MODEL,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages,
            max_tokens=MAX_TOKENS,
        ) as stream:
            async for event in stream:
                sse_sink.emit(translate_event(event))
            final = await stream.get_final_message()
        conversation_store.append(session_id, final)
        messages.append(final)
        if final.stop_reason == "end_turn":
            return
        if final.stop_reason == "tool_use":
            tool_results = []
            for block in final.content:
                if block.type != "tool_use": continue
                result = await tool_dispatch.dispatch(block.name, block.input, ctx)
                tool_results.append({"type": "tool_result", "tool_use_id": block.id, "content": result})
            tool_msg = {"role": "user", "content": tool_results}
            conversation_store.append(session_id, tool_msg)
            messages.append(tool_msg)
            continue
        raise UnexpectedStopReason(final.stop_reason)
```

This is the entire core. Everything else (SSE plumbing, session lifecycle, Firestore schema) stays as-is or deletes.

### 5.4 System prompt storage

Previously lived in `setup_agent.py` as the managed agent's definition. Moves to one of: <!-- orianna: ok -->

- (a) S1 Python constant (`SYSTEM_PROMPT` in `agent_proxy.py`), checked into git. Changes require deploy. <!-- orianna: ok -->
- (b) Firestore singleton `demo-studio-system-prompt/current`, read on S1 boot (with in-memory cache + SIGHUP reload). Changes are live. <!-- orianna: ok -->
- (c) Session-doc override field + (a) as default — per-session A/B prompts.

See Q2 below.

### 5.5 SSE event shape (server-side adaptation)

`stream_translator.py` (new) maps Messages API stream events to the stable browser-facing event types listed in §3.5. Browser UI (session page chat view) should not need to change beyond the name of the events consumed — and those can be held constant if the translator reuses the existing MAL/MAD event names. <!-- orianna: ok -->

## 6. ADR impact

| prior ADR | status | treatment |
|---|---|---|
| **SE** (session-state-encapsulation) | stays | Session doc still exists; still a single-boundary status enum; still gated by `session_store.transition_status`. Minor: `managedSessionId` field dropped. No material change. |
| **BD** (s1-s2-service-boundary) | stays | S2 still owns config; S1 still holds zero config state. Tool handlers proxy to S2 the same way the MCP server did. |
| **MAL** (managed-agent-lifecycle) | **deprecated** | No managed session lifecycle. All MAL artifacts (idle scanner, terminal hook, Slack relay, env vars) removed. Already-landed code reverted in phase D. |
| **MAD** (managed-agent-dashboard-tab) | **deprecated** | No managed agents to dashboard. All MAD artifacts (tab, routes, enrichment, flag) removed. Already-landed code reverted in phase D. |

Retiring MAL + MAD **gracefully**:

- Both plans are `status: implemented` — we do not rewrite history. We create new ADRs, one each, titled `managed-agent-lifecycle-retirement.md` and `managed-agent-dashboard-retirement.md`, that cite this plan as the supersede rationale and enumerate the revert commits. They land in `plans/implemented/work/` once the revert PRs merge. <!-- orianna: ok -->
- Frontmatter `supersedes:` field on the new retirement ADRs points at the original MAL/MAD file paths.
- Architecture bullet in each retirement ADR: "replaced by vanilla Messages API; no managed-session concept exists."
- The MAL/MAD `.md` files themselves stay in `implemented/` — they are historical record of what used to ship. <!-- orianna: ok -->

## 7. Migration

**Nothing is in production.** Demo Studio v3 has not been deployed past staging; the integration branch `integration/demo-studio-v3-waves-1-4` is the current waterline. Greenfield migration: <!-- orianna: ok -->

- **User data:** none exists. No conversation history to port, no session docs to rewrite.
- **Firestore schema:** `demo-studio-sessions` collection exists in staging with a handful of test docs; drop `managedSessionId`, `lastActivityAt`, `managedStatus`, `degradedFields` columns in a one-shot script. Test docs are disposable; a drop-and-recreate of the staging DB is acceptable if the field-drop script has surprises.
- **Integration branch treatment:** `integration/demo-studio-v3-waves-1-4` contains MAL + MAD landed commits. Options: <!-- orianna: ok -->

  - (a) **Revert.** Create revert commits on `integration/...` for every MAL + MAD commit. Clean diff; history preserved; biggest PR. **Recommended.** <!-- orianna: ok -->
  - (b) **Abandon.** Create a new branch `integration/demo-studio-v3-vanilla-api` off the pre-MAL/MAD commit; forward-port the non-MAL/MAD work (SE, BD, waves 1–4). Cleaner trunk; loses integration-branch continuity; forces re-review of already-approved SE/BD commits. <!-- orianna: ok -->
  - (c) **Keep dormant.** Let MAL + MAD code sit in the branch, gated off via `MANAGED_AGENT_DASHBOARD=0` + `MANAGED_SESSION_MONITOR_ENABLED=0` permanently; delete the env vars only. Smallest short-term diff; maximum long-term debt.

  See Q4 below.

## 8. Phases

Phases are orchestration only. No task list in this file. Task decomposition happens in sibling ADRs (Aphelios for complex-track, Kayn for normal-track) once this plan is signed to `approved/`. A plan that adopts Option B will spawn a phase-per-ADR file, not inline tasks. <!-- orianna: ok -->

### A. Agent-proxy rewrite + conversation persistence

Scope:
- Rewrite `agent_proxy.py` as a thin wrapper over `client.messages.stream` (shape in §5.3). <!-- orianna: ok -->
- New `conversation_store.py` with the four-method API in §5.1. <!-- orianna: ok -->
- Firestore subcollection schema (§3.3).
- System prompt moved out of `setup_agent.py` to either (a) constant or (b) Firestore singleton per Q2. <!-- orianna: ok -->
- Unit tests: stream-event translation, tool-use loop branching, Firestore round-trip.

Gates B on: functional single-turn conversation with no tools.

### B. Tool-dispatch registry with all five tools

Scope:
- New `tool_dispatch.py` with `TOOLS` list + `HANDLERS` map (§3.4). <!-- orianna: ok -->
- Handler implementations for `get_schema`, `get_config`, `set_config`, `trigger_factory`. Each reuses an existing S1 client (`config_mgmt_client.py`, `factory_bridge.py`). <!-- orianna: ok -->
- `web_search_20241022` in `TOOLS` but no handler (Anthropic executes).
- Error mapping to TS MCP `server.ts` strings (stable user-facing messages). <!-- orianna: ok -->
- xfail test per tool committed first (Rule 12).

Gates C on: round-trip `set_config` → S2 reflects write within 2 s.

### C. SSE stream adaptation for vanilla streaming format

Scope:
- New `stream_translator.py` maps `messages.stream` events to the stable browser event shape (§3.5 / §5.5). <!-- orianna: ok -->
- Update `/session/{id}/stream` to subscribe to `agent_proxy.run_turn`'s sink rather than the managed-agent event bus.
- Browser UI changes: ideally zero (translator preserves event names); if not zero, patch `session.html` + `static/session.js` to the new event set. <!-- orianna: ok -->

Gates D on: browser renders assistant-text deltas smoothly; tool-use + tool-result indicators show.

### D. Deletion sweep

Scope:
- Remove `managed_session_monitor.py`, `managed_session_client.py`, `setup_agent.py`, `/dashboard/managed-agents/*` routes + UI, all MAL + MAD Firestore reconciliation code. <!-- orianna: ok -->
- Delete env vars from `.env.example`, `deploy.sh`, Cloud Run service YAML. <!-- orianna: ok -->
- Delete the `demo-studio-mcp` repo directory (or archive to `archive/` per team convention). <!-- orianna: ok -->
- Write the two retirement ADRs (MAL-retirement, MAD-retirement) in `plans/implemented/work/` with `supersedes:` frontmatter pointing at the originals. <!-- orianna: ok -->
- Run Grep sweep for any remaining `managedSessionId` / `MANAGED_` references — surface count goes to 0.

Gates E on: S1 boots with neither MCP service env nor managed-agent env set; all tests green.

### E. E2E smoke v2

Scope:
- Same 8 scenarios as Azir's Option A plan (see **Test plan** section below). Implementation adapted to vanilla path.
- Runs on staging against real S2 / S3 / S4 / S5 + real Anthropic Messages API.
- Video + screenshots per Rule 16 scenarios; Figma diff if UI changed.

Gates F on: 8/8 green, back-to-back, in a single recorded run.

### F. Flag flip / ship gate

Scope:
- With Option B, there is no `MANAGED_AGENT_DASHBOARD` flag to flip. The ship gate is a direct cutover: deploy the vanilla-api build to prod, run prod smoke, done.
- Rollback mechanic: since this is greenfield to prod, rollback = redeploy prior Cloud Run revision. No data to restore.

See §9 for the ship-gate checklist.

## Test plan

**E2E smoke v2 — eight scenarios, structural parity with Azir Option A (§4 of that plan), implementation differences noted.**

1. **Empty-session Slack trigger.** Slash command → S1 creates session with `initialContext = {}`. **Option B diff:** no managed session is created; only the Firestore session doc + empty conversation subcollection. Browser opens and sees the generic greeting from the vanilla agent's first turn.

2. **Agent config via tool call → S2.** User says "set the brand to Acme." S1 streams the assistant's decision; `tool_use: set_config` block arrives; `tool_dispatch.dispatch("set_config", ...)` proxies to S2; S2 `/v1/config/{sessionId}` reflects the write within 2 s; `tool_result` block is appended and the follow-up assistant turn confirms. **Option B diff:** tool dispatch is in-process, not over MCP HTTP.

3. **Preview iframe loads from S5.** After ≥1 config write, iframe src resolves to S5 and paints. **Option B diff:** none — S5 is unchanged.

4. **Open in fullview new-tab.** Clicking button opens S5 fullview. **Option B diff:** none.

5. **Build → S3 → S4 round-trip (cold).** User says "build it." `tool_use: trigger_factory` block arrives; handler calls `factory_bridge.trigger_build(session_id)`; S3 returns `projectId`; SSE surfaces build events and eventual verification. **Option B diff:** build is triggered by client-side tool handler, not by an MCP server forwarding to S1 to forward to S3.

6. **Verification pass surfaces in UI.** `verificationStatus = passed` appears in UI. **Option B diff:** none.

7. **Iterate with same projectId (warm).** Same `projectId` reused across second build. **Option B diff:** none.

8. **Verification fail → iterate → pass.** Full iteration loop. **Option B diff:** none — loop is driven by the same tool-use chain.

All 8 green on staging before §9 ship-gate items are checked.

**Additional unit + xfail coverage required before phase gates:**

- `conversation_store` round-trip (write 3 messages, read back, order by `seq`).
- `tool_dispatch` unknown tool → raises `UnknownToolError` → surfaces as `tool_result` with `is_error: true` (loop does not crash).
- `stream_translator` event-shape mapping — one test per Messages API event type.
- Tool-use loop termination: manufactured `stop_reason = "end_turn"` after one round; manufactured `stop_reason = "tool_use"` then `end_turn` for two rounds; manufactured loop that exceeds `MAX_TURNS` safety bound.

Per Rule 12 every implementation commit is preceded by an xfail test on the same branch referencing this plan.

## 9. Ship gate

Cutover to prod when:

- [ ] Phases A–E green on staging.
- [ ] All 8 **Test plan** scenarios green back-to-back, video recorded, per Rule 16.
- [ ] Akali's UI regression pass green against Figma for: session page (empty state), chat + tool-call indicators, iframed preview, fullview new-tab, build progress + SSE log view, verification pass/fail.
- [ ] `demo-studio-mcp` Cloud Run service deleted in GCP console; DNS record if any removed.
- [ ] `.env.example` + deploy.sh contain no `MANAGED_` or `DEMO_STUDIO_MCP_` env refs. <!-- orianna: ok -->
- [ ] Grep sweep for `managedSessionId` / `create_managed_session` / `setup_agent` returns zero hits across S1.
- [ ] MAL + MAD retirement ADRs merged to `plans/implemented/work/`. <!-- orianna: ok -->
- [ ] Prod smoke runbook (Heimerdinger) executes Scenarios 1, 2, 5, 6 against prod within 15 min of deploy; rollback tested (prior Cloud Run revision restore).

No feature flag. Vanilla path is the only path. A bad deploy rolls back by redeploying the prior Cloud Run revision — the prior revision still has the managed-agent code until the deletion sweep phase completes, so during phases A–D rollback is to the managed path. Once phase D merges, the prior revision is the A-phase build (vanilla but fewer tools).

## 10. Open questions

1. **Conversation persistence location.**
   a: Firestore subcollection `demo-studio-sessions/{id}/conversations/{seq}`, one doc per message, indexed by `seq`. <!-- orianna: ok -->
   b: Packed JSON array on the session doc itself, rewritten on each append.
   c: Pure in-memory with reconstruction on S1 restart (via replaying tool calls against current S2 state — lossy for user chat).
   Pick: (a). Subcollection scales past the 1 MB session-doc bound; keeps chat data adjacent to its session but queryable independently.

2. **System-prompt storage.**
   a: S1 Python constant, checked in, deploy-to-change.
   b: Firestore singleton `demo-studio-system-prompt/current` with in-memory cache + SIGHUP reload. <!-- orianna: ok -->
   c: Per-session override field + (a) as default.
   Pick: (a). Deploy friction is acceptable for a prompt that changes once a month; avoids the cache-invalidation bug class; keeps the prompt diffable in PRs.

3. **Tool-result size overflow.**
   a: Truncate tool_result content to 900 KB, append `...[truncated]` marker; never stores raw value.
   b: Store full content in a GCS object under `demo-studio-tool-results/{session}/{seq}`; Firestore doc holds a `truncatedRef` pointer; handler replaces tool_result with pointer on overflow; model sees summary only. <!-- orianna: ok -->
   c: No limit enforcement; trust handlers to return small results and let Firestore 1 MB error surface if exceeded.
   Pick: (a). Simplest. `get_schema` is the only handler that approaches the bound; a 900 KB schema is a symptom of a design problem, not something to engineer around.

4. **Integration-branch treatment.**
   a: Revert MAL + MAD commits on `integration/demo-studio-v3-waves-1-4`. Clean diff, biggest PR. <!-- orianna: ok -->
   b: Abandon the branch; new branch off pre-MAL/MAD, forward-port SE + BD.
   c: Keep dormant; gate off via env flags; delete flags only.
   Pick: (a). Revert is the honest audit trail; forward-port silently loses work; keeping dormant is the worst of both worlds.

5. **Observability without Anthropic console traces.**
   a: S1 emits one structured log per turn (turn_start, turn_end with stop_reason + usage) and one per tool_use/tool_result pair; existing Cloud Run log sink handles aggregation.
   b: Add OpenTelemetry tracing with spans per turn and per tool; export to Cloud Trace.
   c: Do nothing; accept reduced observability as a trade-off cost.
   Pick: (a). Structured logs get us 90 % of what the Anthropic console gave us for near-zero effort; Cloud Trace is a follow-up ADR if the logs prove insufficient.

6. **Agent-health surface without MAD.**
   a: Replace MAD tab with a thin "Recent Turns" tab that lists the last N conversation entries per session — reuses the conversation subcollection, no separate source of truth.
   b: Remove MAD tab entirely; no in-product agent-health surface; rely on Cloud Run metrics + logs.
   c: Keep the MAD tab shell but re-point it at Firestore conversations only.
   Pick: (b). Duong's flow is synchronous — he watches the chat live. A separate "are the agents okay" tab is a managed-agent-era artifact. If he later wants one, it can come back as its own ADR.

## 11. Honest trade-offs vs Option A (Azir's plan)

**What Option B costs that Option A preserves:**

- **Anthropic-console trace visibility.** The managed agent emits every turn + tool_call to Anthropic's dashboard, free. Vanilla API gets us only what we log ourselves. For production incident forensics this matters; for the current single-tenant dev loop it does not. Mitigation: §10 Q5 structured logging.
- **Long-running / disconnected sessions.** A managed agent can keep running for days while the user is offline; a vanilla-API session is only alive as long as S1's process holds the conversation in memory + Firestore. For the current "user sits at browser" flow this is not a limitation. If a future product pivot introduces an async-agent mode, we would have to rebuild this.
- **Server-side conversation state.** Anthropic holds message history for us. Vanilla requires we build `conversation_store.py` and get its correctness right (ordering, truncation, replay). More code we own + more bugs we can ship. Mitigation: it is a small module with clear invariants; the risk is bounded. <!-- orianna: ok -->
- **Tool-use loop correctness.** We write the dispatcher, the max-iter guard, the error handling on unknown tools. The managed agent had this free. Risk surface: infinite loops, stuck tools, unhandled exceptions. Mitigation: TDD on `tool_dispatch` with a hard `MAX_TURNS=20` cap and explicit `UnknownToolError` path.
- **MCP ecosystem leverage.** If at some future point we want to expose Demo Studio tools to other Anthropic clients (Claude Desktop, another agent in the roster), MCP is the protocol. Vanilla path re-internalizes tool surface into S1. Mitigation: a future MCP shim is a small wrap around the existing handler registry — we do not lose optionality, we defer it.

**What Option B buys:**

- **~2 services deleted.** `demo-studio-mcp` Cloud Run goes away; `managed_session_monitor` background task goes away. Deploy surface shrinks to one container. No more "MCP 503 kills everything."
- **~2 ADRs of code deleted.** MAL + MAD retire with a net-negative line count. The code was written, reviewed, approved, landed — deleting it reclaims all of that as architectural simplicity.
- **Single auth posture.** One secret (`ANTHROPIC_API_KEY`) instead of three (Anthropic vault + MCP bearer + operator cookie). One rotation procedure. One failure mode.
- **No drift between Firestore and Anthropic.** We are the single source of truth for session state. MAL's whole premise (Anthropic's view is authoritative, reconcile via scanner) evaporates — there is no second view.
- **No orphaned managed sessions.** They cannot leak if they do not exist. The cost-control concern that spawned MAL disappears.
- **Simpler mental model.** One file (`agent_proxy.py`, shape in §5.3) is the agent. A new engineer can understand the full execution model in 30 lines instead of tracing a managed-session lifecycle across four services. <!-- orianna: ok -->
- **Web search** comes along for free via Anthropic's built-in `web_search_20241022`. Karma's in-process MCP plan notes the TS MCP has no web_search — we get it by switching tracks.

**Where this plan could be wrong:**

- If Anthropic's managed-agent product matures into something materially better than vanilla (e.g. improved caching, cheaper pricing tier for managed turns, a first-class MCP-resources binding), deleting our integration closes a door we might want open. The current evidence (pricing parity, both APIs GA, no managed-exclusive features we need) says this is unlikely. But it is a bet.
- The port itself has schedule risk. The managed-agent code has been shaken out over multiple waves; the vanilla tool-use loop is new code with new bugs. A conservative Option A — Karma's MCP merge — ships the same flow faster because less is rewritten.

Net: Option A is lower-risk-to-ship; Option B is lower-risk-to-maintain. Duong picks which risk profile he values more given current conditions.

## 12. Handoff

No implementer is named here — `owner:` is authorship only (swain). Evelynn assigns post-signature.

| Phase | Suggested role | Rationale |
|---|---|---|
| A. Agent-proxy rewrite + conversation persistence | Viktor (complex builder) | Multi-surface: SDK wiring, new Firestore collection, message-loop correctness. TDD-critical. |
| B. Tool-dispatch registry | Viktor (continuing) or Jayce (new-feature builder) | Registry + four handler ports. Shares context with phase A. |
| C. SSE stream adaptation | Viktor (continuing) | Translator + route rewire. Tightly coupled to the agent_proxy stream sink. |
| D. Deletion sweep | Viktor or Ekko (quick-exec) | Mechanical delete; modest risk. Ekko if phase D splits early. |
| E. E2E smoke v2 | Vi (test impl) from Caitlyn's test plan | Rule 15 Playwright flows for all 8 **Test plan** scenarios. |
| F. Deploy + MCP-service retirement | Heimerdinger (DevOps advice) → Ekko (execution) | GCP Cloud Run revision cutover + delete of `demo-studio-mcp` service + env-var cleanup on the deploy config. |
| UI adaptation (if any) | Seraphine (frontend impl) | Likely minor — SSE event names are preserved by the translator. Only touched if §5.5 forces a browser-side change. |
| PR review | Senna (code+security) + Lucian (plan fidelity) | Rule 18. |
| UI QA (Rule 16) | Akali | Playwright flow + Figma diff before UI PR. |

Per the plan-structure linter and Rule 11, no rebase is allowed on any of the phase branches; merges only.

## Tasks

Orchestration-level coordination only. No phase decomposition here (each phase's task list is written by Aphelios/Kayn after this plan signs through `approved/`, per §12 Handoff). <!-- orianna: ok -->

- [ ] **T.COORD.1** — Resolve §10 open questions 1–6 with Duong and record picks inline in this file. kind: coord | estimate_minutes: 30
- [ ] **T.COORD.2** — Pick between Option A (Azir v2 managed+MCP-merge) and Option B (this plan vanilla API); only the chosen plan advances. kind: coord | estimate_minutes: 20
- [ ] **T.COORD.3** — If Option B picked: spawn phase-A ADR + task decomposition via Aphelios. kind: coord | estimate_minutes: 10
- [ ] **T.COORD.4** — Sequence phases A → B → C → D → E → F per §8; gate each on prior phase ship-criteria. kind: coord | estimate_minutes: 20
- [ ] **T.COORD.5** — Run §9 ship-gate checklist review before prod cutover. kind: coord | estimate_minutes: 30
- [ ] **T.COORD.6** — Post-cutover, write MAL-retirement and MAD-retirement ADRs and archive this plan to `plans/implemented/work/`. kind: coord | estimate_minutes: 20 <!-- orianna: ok -->

## 13. Out of scope

- **S3 `projectId` reuse + S3→S4 auto-trigger** (covered by Azir §2.2) — orthogonal to agent execution model; lands on whichever track Duong picks.
- **S5 fullview** (Azir §2.3) — same.
- **S1 UI empty-session + iframe + logs SSE** (Azir §2.4 in `plans/proposed/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md`) — same flow-level surface; the vanilla-agent substitution does not change it. <!-- orianna: ok -->
- **Replacing Firestore with another session store** — not on the table.
- **Per-user auth / multi-tenancy** — not on the table.
- **Custom model router / multi-model routing** — we use `claude-sonnet-4-6` as declared; model selection is one constant.
- **Prompt caching optimization** — a separate ADR once the system prompt stabilizes; initial ship runs without explicit cache hints and accepts baseline token cost.

---

## Task breakdown (Aphelios — inlined from sibling -tasks.md per D1A)


# Task decomposition — Demo Studio v3 Vanilla Messages API Ship (Option B)

<!-- orianna: ok — all bare module, file, env-var, HTTP-path, and Firestore-path tokens in this file (agent_proxy.py, conversation_store.py, tool_dispatch.py, stream_translator.py, config_mgmt_client.py, factory_bridge.py, setup_agent.py, managed_session_client.py, managed_session_monitor.py, session_store.py, session.html, static/session.js, .env.example, deploy.sh, server.ts, mcp_app.py, main.py, firestore/indexes.json, /session/{id}/chat, /session/{id}/stream, /dashboard/managed-agents/*, /v1/config/{id}, demo-studio-sessions/{id}/conversations/{seq}, DEMO_STUDIO_MCP_URL, DEMO_STUDIO_MCP_TOKEN, MANAGED_AGENT_ID, MANAGED_ENVIRONMENT_ID, MANAGED_VAULT_ID, MANAGED_AGENT_DASHBOARD, MANAGED_SESSION_MONITOR_ENABLED, IDLE_WARN_MINUTES, IDLE_TERMINATE_MINUTES, SCAN_INTERVAL_SECONDS, ANTHROPIC_API_KEY, CLAUDE_MODEL, MAX_TOKENS, MAX_TURNS, SYSTEM_PROMPT, ConversationStore.append, ConversationStore.load, client.messages.stream, tool_dispatch.dispatch, tool_result.content, config_mgmt_client.fetch_schema, config_mgmt_client.fetch_config, config_mgmt_client.patch_config, factory_bridge.trigger_build, web_search_20241022, integration/demo-studio-v3-waves-1-4, integration/demo-studio-v3-vanilla-api, tdd-gate.yml, managed-agent-lifecycle-retirement.md, managed-agent-dashboard-retirement.md) reference files, routes, Firestore paths, env vars, SDK methods, or branches inside the missmp/company-os work workspace OR are prospective future-ADR filenames. This task file creates no strawberry-agents files under those names; parent plan carries the same claim-contract preamble. -->

## Context

Parent: `plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md` <!-- orianna: ok -->
(follow through `approved/` and `in-progress/` subdirs as the gate promotes it; frontmatter `parent_plan:` carries the basename). <!-- orianna: ok -->


This file decomposes phases A–F of the parent's §8 into tasks. Rule 12 (xfail test before impl on same branch) is honored: every `feat` / `refactor` task has a preceding `test` task. Per-task `estimate_minutes` is capped at 60 (plan-structure §D4); larger units are split. Xayah's parallel test-plan file provides the concrete assertions; tasks here cite DoD hooks that Xayah's file will fill in.

Executor tier notes (parent §12 Handoff): Phase A/B/C → Viktor (complex builder). Phase D → Ekko/Jayce (mechanical). Phase E → Vi off Xayah's test plan. Phase F → Heimerdinger + Ekko.

## Phase dependency graph

```
A (agent_proxy + conv_store + stream_translator)
   └── blocks ──► B (tool_dispatch + five handlers)
                     └── blocks ──► C (SSE route rewire + UI event names)
                                       └── blocks ──► E (E2E smoke)
                                                        └── blocks ──► F (ship gate)
D (deletion sweep) runs parallel with A/B/C, must land before E.
```

Inter-phase blocking explicit: A→B, B→C, A/B/C→E, D→E, E→F.

## Test plan

Test-authoring authority is **Xayah** (see Sona's parallel brief). Xayah's test-plan file is the source of truth for concrete assertions across all phases; this file references Xayah's test IDs through DoD hooks ("xfail test `T.A.1` committed", "E2E scenario N green"). <!-- orianna: ok -->

Minimum coverage expected per parent plan's "Test plan" section:

1. **E2E smoke v2 — 8 scenarios** against staging (parent §"Test plan" 1–8): empty-session Slack trigger, agent config via tool call → S2, preview iframe from S5, fullview new-tab, build cold S3→S4 round-trip, verification pass in UI, iterate-warm same projectId, verification fail→iterate→pass. Each with video + screenshots per Rule 16.
2. **Unit + xfail** per parent "Test plan" tail: `conversation_store` round-trip (task T.A.1 below), <!-- orianna: ok --> `tool_dispatch` unknown-tool + `is_error: true` surface (T.B.1), <!-- orianna: ok --> `stream_translator` per-event mapping (T.A.5a–T.A.5f), tool-use loop termination + `MAX_TURNS` cap (T.A.7a–T.A.7c). <!-- orianna: ok -->
3. **Per Rule 12** every impl commit in this breakdown is preceded by an xfail commit on the same branch; the xfail commit cites the parent plan slug `2026-04-21-demo-studio-v3-vanilla-api-ship`.

Xayah's file, once published, will enumerate exact assertion IDs mapped back to the T.* IDs below.

## Tasks

Phase group labels use **T.<PHASE>.<N>** (parent §8 phase letters A–F). Tasks for a single large work unit split into lettered sub-tasks (e.g. T.A.5a..f) to respect the 60-min cap.

### Phase A — Agent-proxy rewrite + conversation persistence

Branch: `integration/demo-studio-v3-vanilla-api` or the revert-branch per parent §7 Q4 pick (a). <!-- orianna: ok -->
Anchor: parent §3.3, §3.4, §5.1, §5.3, §5.4.

- [ ] **T.A.1** — Add xfail test for `conversation_store` Firestore round-trip. kind: test | estimate_minutes: 45 | blocked_by: none | files: `company-os/tools/demo-studio-v3/tests/test_conversation_store.py` (new) | detail: xfail unit test asserting `ConversationStore.append` + `ConversationStore.load` round-trip ordering by `seq` (write 3 messages out-of-order, read back ordered, assert `seq` monotonic). Parent §3.3. Firestore emulator-backed. | DoD: xfail test committed; CI `tdd-gate.yml` sees it. <!-- orianna: ok -->
- [ ] **T.A.2a** — Implement `ConversationStore.append` method. kind: feat | estimate_minutes: 45 | blocked_by: T.A.1 | files: `company-os/tools/demo-studio-v3/conversation_store.py` (new) | detail: `append(session_id, message) -> seq` using Firestore transaction to compute monotonic `seq` (read max + 1, do not trust timestamps). Schema per parent §3.3. | DoD: append path unit test green; transaction retries on contention. <!-- orianna: ok -->
- [ ] **T.A.2b** — Implement `ConversationStore.load` + `load_since`. kind: feat | estimate_minutes: 45 | blocked_by: T.A.2a | files: `company-os/tools/demo-studio-v3/conversation_store.py` (extend) | detail: `load(session_id)` returns ordered list; `load_since(session_id, seq)` returns tail for SSE replay. Order strictly by `seq` field, not timestamps. | DoD: T.A.1 flips green for round-trip case. <!-- orianna: ok -->
- [ ] **T.A.2c** — Implement `ConversationStore.truncate_for_model`. kind: feat | estimate_minutes: 45 | blocked_by: T.A.2b | files: `company-os/tools/demo-studio-v3/conversation_store.py` (extend) | detail: `truncate_for_model(messages, max_tokens)` drops oldest non-system messages until under limit; preserves tool_use/tool_result pairing. Parent §5.1. | DoD: unit test on 20-message transcript truncated to 5k tokens preserves last user+assistant+tool_result chain. <!-- orianna: ok -->
- [ ] **T.A.2d** — Enforce single-boundary invariant on `conversation_store.py`. kind: refactor | estimate_minutes: 30 | blocked_by: T.A.2c | files: repo-wide Grep + `company-os/tools/demo-studio-v3/conversation_store.py` | detail: Grep confirms nothing outside `conversation_store.py` reads/writes the `demo-studio-sessions/{id}/conversations/{seq}` subcollection directly (mirrors SE boundary). Add a module-header comment pinning the invariant. Parent §5.1. | DoD: Grep returns one file. <!-- orianna: ok -->
- [ ] **T.A.3** — Add xfail test for `SYSTEM_PROMPT` constant wiring. kind: test | estimate_minutes: 30 | blocked_by: none | files: `company-os/tools/demo-studio-v3/tests/test_system_prompt.py` (new) | detail: xfail asserts `from agent_proxy import SYSTEM_PROMPT` returns a non-empty string (module-level constant), and `setup_agent` is not imported from S1 entry. Parent §5.4 + §10 Q2 pick (a). | DoD: xfail committed; references parent §5.4. <!-- orianna: ok -->
- [ ] **T.A.4** — Extract `SYSTEM_PROMPT` to `agent_proxy.py`; decommission `setup_agent` imports. kind: refactor | estimate_minutes: 60 | blocked_by: T.A.3 | files: `company-os/tools/demo-studio-v3/agent_proxy.py`, `company-os/tools/demo-studio-v3/setup_agent.py` | detail: Lift system-prompt string out of `setup_agent.py` into `agent_proxy.py` as module-level `SYSTEM_PROMPT: str`. Mark `setup_agent.py` deprecated; full delete is phase D (T.D.1). Remove remaining `setup_agent` imports. | DoD: T.A.3 flips green; Grep `from setup_agent` returns 0 hits outside `setup_agent.py` itself. <!-- orianna: ok -->
- [ ] **T.A.5a** — Add xfail test: `stream_translator` maps `content_block_start`. kind: test | estimate_minutes: 20 | blocked_by: none | files: `company-os/tools/demo-studio-v3/tests/test_stream_translator.py` (new) | detail: xfail: `content_block_start` event → no browser event emitted (consumed for state only). Parent §5.5. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.5b** — Add xfail test: text `content_block_delta` maps to `text_delta`. kind: test | estimate_minutes: 20 | blocked_by: T.A.5a | files: `company-os/tools/demo-studio-v3/tests/test_stream_translator.py` (extend) | detail: xfail: text delta → `{event: "text_delta", data: {text: "..."}}`. Parent §3.5. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.5c** — Add xfail test: tool_use `content_block_delta` maps to `tool_use`. kind: test | estimate_minutes: 20 | blocked_by: T.A.5a | files: `company-os/tools/demo-studio-v3/tests/test_stream_translator.py` (extend) | detail: xfail: tool_use input_json_delta accumulates then emits `{event: "tool_use", data: {name, input}}` on `content_block_stop`. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.5d** — Add xfail test: `message_delta` with stop_reason maps to `turn_end`. kind: test | estimate_minutes: 20 | blocked_by: T.A.5a | files: `company-os/tools/demo-studio-v3/tests/test_stream_translator.py` (extend) | detail: xfail: `message_delta` carrying `stop_reason` + `usage` → `{event: "turn_end", data: {stop_reason, usage}}`. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.5e** — Add xfail test: error event maps to `error`. kind: test | estimate_minutes: 20 | blocked_by: T.A.5a | files: `company-os/tools/demo-studio-v3/tests/test_stream_translator.py` (extend) | detail: xfail: error frame → `{event: "error", data: {code, message}}`. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.5f** — Add xfail test: `message_stop` maps to stream close. kind: test | estimate_minutes: 20 | blocked_by: T.A.5a | files: `company-os/tools/demo-studio-v3/tests/test_stream_translator.py` (extend) | detail: xfail: `message_stop` → no browser event but signals adapter to close sink. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.6a** — Implement `stream_translator.py` text + tool_use paths. kind: feat | estimate_minutes: 60 | blocked_by: T.A.5b, T.A.5c | files: `company-os/tools/demo-studio-v3/stream_translator.py` (new) | detail: Pure module; no I/O. Map Messages API streaming events for text deltas and tool_use blocks to parent §3.5 stable browser events. | DoD: T.A.5b + T.A.5c flip green; Grep confirms no network/Firestore imports. <!-- orianna: ok -->
- [ ] **T.A.6b** — Implement `stream_translator.py` turn_end + error + stop paths. kind: feat | estimate_minutes: 45 | blocked_by: T.A.6a, T.A.5d, T.A.5e, T.A.5f | files: `company-os/tools/demo-studio-v3/stream_translator.py` (extend) | detail: Add `message_delta` → `turn_end`, error frame → `error`, `message_stop` close signal. | DoD: T.A.5d/e/f flip green. <!-- orianna: ok -->
- [ ] **T.A.7a** — Add xfail test: tool-use loop `end_turn` terminates cleanly. kind: test | estimate_minutes: 30 | blocked_by: T.A.1, T.A.5a | files: `company-os/tools/demo-studio-v3/tests/test_agent_proxy_loop.py` (new) | detail: xfail with mocked stream: `stop_reason=end_turn` after one round persists assistant message and returns. Parent §5.3 pseudocode. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.7b** — Add xfail test: tool-use loop dispatches tool then terminates. kind: test | estimate_minutes: 30 | blocked_by: T.A.7a | files: `company-os/tools/demo-studio-v3/tests/test_agent_proxy_loop.py` (extend) | detail: xfail: `tool_use` → dispatch (mocked) → append `tool_result` → follow-up turn `end_turn`. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.7c** — Add xfail test: tool-use loop hits `MAX_TURNS` cap. kind: test | estimate_minutes: 30 | blocked_by: T.A.7a | files: `company-os/tools/demo-studio-v3/tests/test_agent_proxy_loop.py` (extend) | detail: xfail: manufactured infinite tool-use loop raises `MaxTurnsExceeded` at `MAX_TURNS=20`. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.A.8a** — Implement `agent_proxy.run_turn` skeleton + `messages.stream` wiring. kind: feat | estimate_minutes: 60 | blocked_by: T.A.2b, T.A.4, T.A.6b, T.A.7a | files: `company-os/tools/demo-studio-v3/agent_proxy.py` (rewrite) | detail: Skeleton per parent §5.3: load conversation, append user msg, enter `client.messages.stream` ctx manager, fan events through `stream_translator` into `sse_sink`. No tool handling in this task (stub). | DoD: T.A.7a flips green. <!-- orianna: ok -->
- [ ] **T.A.8b** — Implement tool-use branch in `run_turn` with dispatch stub. kind: feat | estimate_minutes: 45 | blocked_by: T.A.8a, T.A.7b | files: `company-os/tools/demo-studio-v3/agent_proxy.py` (extend) | detail: On `stop_reason=="tool_use"`: extract each `tool_use` block; call `tool_dispatch.dispatch` (raises `NotImplementedError` until phase B — test uses mock); append `tool_result` blocks; loop. | DoD: T.A.7b flips green. <!-- orianna: ok -->
- [ ] **T.A.8c** — Implement `MAX_TURNS` safety cap + `UnexpectedStopReason`. kind: feat | estimate_minutes: 30 | blocked_by: T.A.8b, T.A.7c | files: `company-os/tools/demo-studio-v3/agent_proxy.py` (extend) | detail: Hard cap at `MAX_TURNS=20`; raise `MaxTurnsExceeded`. Unknown `stop_reason` raises `UnexpectedStopReason`. Module exports: `run_turn`, `SYSTEM_PROMPT`, `CLAUDE_MODEL="claude-sonnet-4-6"`, `MAX_TOKENS`, `MAX_TURNS`. | DoD: T.A.7c flips green; Grep confirms no `managed_session_client` / `setup_agent` imports. <!-- orianna: ok -->
- [ ] **T.A.9** — Declare Firestore composite index for conversations subcollection. kind: feat | estimate_minutes: 45 | blocked_by: T.A.2b | files: `company-os/tools/demo-studio-v3/firestore/indexes.json` (or equivalent), `company-os/tools/demo-studio-v3/conversation_store.py` | detail: Composite index `demo-studio-sessions/{id}/conversations` ordered by `seq ASC`. If no declarative index config exists in the work workspace, document in `conversation_store.py` docstring and defer creation to phase F deploy (T.F.2). Parent §3.3. | DoD: index config committed OR deferred task explicitly linked. <!-- orianna: ok -->

Phase A exit: single-turn conversation runs end-to-end with no tools on staging Messages API; Firestore round-trip verified; SSE streams text deltas. Gates phase B.

### Phase B — Tool-dispatch registry with all five tools

Anchor: parent §3.4, §5.2.

- [ ] **T.B.1a** — Add xfail test: `tool_dispatch.dispatch` unknown-tool returns is_error. kind: test | estimate_minutes: 30 | blocked_by: T.A.8c | files: `company-os/tools/demo-studio-v3/tests/test_tool_dispatch.py` (new) | detail: xfail: `dispatch("nonexistent", {}, ctx)` returns `tool_result` dict with `is_error: true`, does not raise. Parent §3.4. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.B.1b** — Add xfail test: `TOOLS` export shape + `HANDLERS` key parity. kind: test | estimate_minutes: 30 | blocked_by: T.B.1a | files: `company-os/tools/demo-studio-v3/tests/test_tool_dispatch.py` (extend) | detail: xfail: `TOOLS` is non-empty list of dicts each with `name` + (`input_schema` OR `type`); `HANDLERS` keys equal the handler-bearing subset of `TOOLS` names (excluding `web_search`). | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.B.2a** — Implement `tool_dispatch.py` skeleton + TOOLS list. kind: feat | estimate_minutes: 45 | blocked_by: T.B.1b | files: `company-os/tools/demo-studio-v3/tool_dispatch.py` (new) | detail: Export `TOOLS` (5 defs: 4 custom + `web_search_20241022`), `HANDLERS` (empty dict populated in T.B.4/6/8). Parent §3.4. | DoD: T.B.1b flips green; web_search entry has `type: web_search_20241022`. <!-- orianna: ok -->
- [ ] **T.B.2b** — Implement `dispatch` function with unknown-tool path. kind: feat | estimate_minutes: 30 | blocked_by: T.B.2a | files: `company-os/tools/demo-studio-v3/tool_dispatch.py` (extend) | detail: `async def dispatch(name, input, ctx) -> dict`. Unknown tool → `{"is_error": True, "content": "unknown tool: " + name}`. Handler-present names delegate to `HANDLERS[name]`. | DoD: T.B.1a flips green. <!-- orianna: ok -->
- [ ] **T.B.3** — Add xfail tests for `get_schema` + `get_config` handlers. kind: test | estimate_minutes: 45 | blocked_by: T.B.2b | files: `company-os/tools/demo-studio-v3/tests/test_tool_dispatch.py` (extend) | detail: 2 xfail cases: (a) `get_schema` handler calls mocked `config_mgmt_client.fetch_schema()` once and wraps result as `tool_result.content`. (b) `get_config` handler calls `fetch_config(session_id)` similarly. Parent §5.2. | DoD: 2 xfail cases. <!-- orianna: ok -->
- [ ] **T.B.4** — Implement `get_schema` + `get_config` handlers. kind: feat | estimate_minutes: 60 | blocked_by: T.B.3 | files: `company-os/tools/demo-studio-v3/tool_dispatch.py` (extend) | detail: Thin proxies to existing `config_mgmt_client.py`. Lazy import. Error mapping (NotFound/Unauthorized/ServiceUnavailable) mirrors TS MCP `server.ts` user-facing strings per parent §5.2. | DoD: T.B.3 flips green; Grep-compare on 3 error paths against `server.ts`. <!-- orianna: ok -->
- [ ] **T.B.5a** — Add xfail test: `set_config` success path. kind: test | estimate_minutes: 30 | blocked_by: T.B.2b | files: `company-os/tools/demo-studio-v3/tests/test_tool_dispatch.py` (extend) | detail: xfail: `set_config` handler with valid `(path, value)` calls `config_mgmt_client.patch_config(session_id, path, value)` exactly once. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.B.5b** — Add xfail tests: `set_config` 403 + 503 error mapping. kind: test | estimate_minutes: 30 | blocked_by: T.B.5a | files: `company-os/tools/demo-studio-v3/tests/test_tool_dispatch.py` (extend) | detail: 2 xfail cases: 403 → "unauthorized" string; 503 → "config service unavailable" string matching TS MCP `server.ts`. | DoD: 2 xfail cases. <!-- orianna: ok -->
- [ ] **T.B.6** — Implement `set_config` handler + TS MCP `server.ts` string parity. kind: feat | estimate_minutes: 60 | blocked_by: T.B.5b | files: `company-os/tools/demo-studio-v3/tool_dispatch.py` (extend) | detail: `handle_set_config` proxies `config_mgmt_client.patch_config`. Catch-and-map S2 errors to exact user-facing strings from TS MCP `server.ts`. Add a compare-table comment listing pairs. Parent §5.2. | DoD: T.B.5a + T.B.5b flip green. <!-- orianna: ok -->
- [ ] **T.B.7** — Add xfail test for `trigger_factory` handler. kind: test | estimate_minutes: 30 | blocked_by: T.B.2b | files: `company-os/tools/demo-studio-v3/tests/test_tool_dispatch.py` (extend) | detail: xfail: `trigger_factory` handler calls `factory_bridge.trigger_build(session_id)` once; wraps returned `projectId` into `tool_result.content` dict. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.B.8** — Implement `trigger_factory` handler + web_search passthrough doc. kind: feat | estimate_minutes: 45 | blocked_by: T.B.7 | files: `company-os/tools/demo-studio-v3/tool_dispatch.py` (extend) | detail: `handle_trigger_factory` proxies to `factory_bridge.trigger_build`. Module docstring notes `web_search_20241022` has no handler (Anthropic executes server-side; content blocks pass through `agent_proxy` unmodified). Parent §3.4. | DoD: T.B.7 flips green; HANDLERS has 4 keys. <!-- orianna: ok -->
- [ ] **T.B.9** — Wire `agent_proxy.run_turn` to real `tool_dispatch.dispatch`. kind: feat | estimate_minutes: 45 | blocked_by: T.B.4, T.B.6, T.B.8 | files: `company-os/tools/demo-studio-v3/agent_proxy.py` | detail: Replace `NotImplementedError` stub (planted in T.A.8b) with `await tool_dispatch.dispatch(block.name, block.input, ctx)`. Pass `SessionContext` with `session_id`, auth, request-scoped clients. | DoD: integration test — `set_config` from mocked Anthropic stream reaches S2 and writes. <!-- orianna: ok -->

Phase B exit: round-trip `set_config` → S2 reflects write within 2 s (parent §8 phase B gate). Gates phase C.

### Phase C — SSE stream adaptation for vanilla streaming format

Anchor: parent §3.5, §5.5.

- [ ] **T.C.1a** — Add xfail test: `/session/{id}/stream` emits stable event set only. kind: test | estimate_minutes: 45 | blocked_by: T.B.9 | files: `company-os/tools/demo-studio-v3/tests/test_session_stream_route.py` (new) | detail: xfail against in-memory FastAPI/Starlette client: route emits SSE events only in `text_delta | tool_use | tool_result | turn_end | error`. No legacy managed-agent event names. Parent §3.5. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.C.1b** — Add xfail test: `turn_end` payload shape. kind: test | estimate_minutes: 30 | blocked_by: T.C.1a | files: `company-os/tools/demo-studio-v3/tests/test_session_stream_route.py` (extend) | detail: xfail: `turn_end` carries `stop_reason` + `usage` per parent §3.5. | DoD: 1 xfail case. <!-- orianna: ok -->
- [ ] **T.C.2a** — Rewire `/session/{id}/stream` to subscribe to `agent_proxy.run_turn` sink. kind: refactor | estimate_minutes: 60 | blocked_by: T.C.1b | files: `company-os/tools/demo-studio-v3/main.py`, `company-os/tools/demo-studio-v3/agent_proxy.py` (sink adapter) | detail: Replace managed-agent event subscription with `sse_sink` adapter agent_proxy writes into. Remove `managed_session_client` import from this route. | DoD: T.C.1a flips green; Grep confirms `managed_session_client` not imported by `main.py`. <!-- orianna: ok -->
- [ ] **T.C.2b** — Wire `/session/{id}/chat` to persist user message and trigger `run_turn`. kind: refactor | estimate_minutes: 45 | blocked_by: T.C.2a | files: `company-os/tools/demo-studio-v3/main.py` | detail: `/session/{id}/chat` accepts user text, writes to `conversation_store`, spawns `agent_proxy.run_turn` (async task or direct handler) which feeds the live SSE sink. | DoD: T.C.1b flips green; end-to-end chat→stream handshake works against local Anthropic mock. <!-- orianna: ok -->
- [ ] **T.C.3** — Add xfail test: browser event-name stability. kind: test | estimate_minutes: 30 | blocked_by: T.C.1a | files: `company-os/tools/demo-studio-v3/tests/test_session_stream_route.py` (extend) | detail: xfail: SSE stream in `EventSource`-style harness asserts event-name set equals parent §3.5. Parent §5.5 target: zero UI delta. | DoD: 1 xfail case; if flips green after T.C.2b lands, T.C.4 is a no-op. <!-- orianna: ok -->
- [ ] **T.C.4** — Patch `session.html` + `static/session.js` for new event set (conditional). kind: feat | estimate_minutes: 60 | blocked_by: T.C.3 | files: `company-os/tools/demo-studio-v3/session.html`, `company-os/tools/demo-studio-v3/static/session.js` | detail: **Only if T.C.3 still fails after T.C.2b.** Update `EventSource` handlers to consume `text_delta` / `tool_use` / `tool_result` / `turn_end` / `error`. Seraphine is the executor. | DoD: T.C.3 flips green; if skipped, closeout commit body notes skipped. <!-- orianna: ok -->

Phase C exit: browser renders text deltas smoothly; tool-use + tool-result indicators visible. Gates phase E.

### Phase D — Deletion sweep

Runs parallel with A/B/C; **must complete before phase E** to avoid dead-reference test churn.
Anchor: parent §4, §6, §7 Q4 pick (a).

- [ ] **T.D.1** — Delete `setup_agent.py` + `managed_session_client.py` + `managed_session_monitor.py`. kind: chore | estimate_minutes: 30 | blocked_by: T.A.4 | files: `company-os/tools/demo-studio-v3/setup_agent.py`, `company-os/tools/demo-studio-v3/managed_session_client.py`, `company-os/tools/demo-studio-v3/managed_session_monitor.py` (all removed) | detail: `git rm` the three files. Grep confirms zero hits for `managed_session_client`/`managed_session_monitor`/`setup_agent` outside the deletion commit. Parent §4. | DoD: S1 imports cleanly; Grep clean. <!-- orianna: ok -->
- [ ] **T.D.2a** — Remove `/dashboard/managed-agents/*` routes + handlers. kind: chore | estimate_minutes: 45 | blocked_by: none | files: `company-os/tools/demo-studio-v3/main.py` (route handlers) | detail: Delete the `/dashboard/managed-agents/*` route group and request handlers. Parent §4 + §6. | DoD: Grep `managed-agents` returns 0 hits in routes. <!-- orianna: ok -->
- [ ] **T.D.2b** — Remove MAD dashboard UI tab + enrichment modules. kind: chore | estimate_minutes: 45 | blocked_by: T.D.2a | files: `company-os/tools/demo-studio-v3/session.html` + `static/` (dashboard tab markup), MAD enrichment modules (Grep-identify) | detail: Delete Managed Agents tab markup, the enrichment layer reconciling Firestore with Anthropic's managed-session list, and the `MANAGED_AGENT_DASHBOARD` feature flag plumbing. | DoD: Grep returns 0 for `managed-agents`, `MANAGED_AGENT_DASHBOARD`, `managedStatus`, `degradedFields`. <!-- orianna: ok -->
- [ ] **T.D.3** — Remove MAL terminal-transition hook from `session_store`. kind: chore | estimate_minutes: 45 | blocked_by: none | files: `company-os/tools/demo-studio-v3/session_store.py` | detail: Delete "on terminal transition, stop managed session" branch inside `transition_status`. Delete `lastActivityAt` Firestore writes (parent §4). Keep SE boundary intact. | DoD: existing `session_store` unit tests green; Grep `stop_managed_session|lastActivityAt` → 0. <!-- orianna: ok -->
- [ ] **T.D.4** — Scrub env vars from `.env.example` + `deploy.sh` + Cloud Run YAML. kind: chore | estimate_minutes: 30 | blocked_by: T.D.1 | files: `company-os/tools/demo-studio-v3/.env.example`, `company-os/tools/demo-studio-v3/deploy.sh`, deploy config YAML | detail: Remove `DEMO_STUDIO_MCP_URL`, `DEMO_STUDIO_MCP_TOKEN`, `MANAGED_AGENT_ID`, `MANAGED_ENVIRONMENT_ID`, `MANAGED_VAULT_ID`, `MANAGED_AGENT_DASHBOARD`, `MANAGED_SESSION_MONITOR_ENABLED`, `IDLE_WARN_MINUTES`, `IDLE_TERMINATE_MINUTES`, `SCAN_INTERVAL_SECONDS`. Keep `ANTHROPIC_API_KEY`, `CLAUDE_MODEL`, `MAX_TOKENS`, `MAX_TURNS`. Parent §4. | DoD: ship-gate §9 env-var bullet green. <!-- orianna: ok -->
- [ ] **T.D.5** — Delete `company-os/tools/demo-studio-mcp/` repo directory. kind: chore | estimate_minutes: 30 | blocked_by: T.D.4 | files: `company-os/tools/demo-studio-mcp/` | detail: `git rm -r` the MCP service directory (or archive per team convention — see OQ-D1). Cloud Run service delete is T.F.4. Parent §4. | DoD: directory gone from S1 repo tree; CI config refs updated. <!-- orianna: ok -->
- [ ] **T.D.6a** — Author MAL-retirement ADR. kind: chore | estimate_minutes: 45 | blocked_by: T.D.1, T.D.3 | files: `plans/implemented/work/2026-04-XX-managed-agent-lifecycle-retirement.md` (new) | detail: New ADR with `supersedes:` frontmatter pointing at `plans/implemented/work/2026-04-20-managed-agent-lifecycle.md`. Body: cite parent plan as rationale, enumerate revert commit SHAs, include bullet "replaced by vanilla Messages API; no managed-session concept exists." Commit direct to main (Rule 4). | DoD: file in `plans/implemented/work/`; `supersedes:` populated. <!-- orianna: ok -->
- [ ] **T.D.6b** — Author MAD-retirement ADR. kind: chore | estimate_minutes: 45 | blocked_by: T.D.2b | files: `plans/implemented/work/2026-04-XX-managed-agent-dashboard-retirement.md` (new) | detail: Mirror of T.D.6a for MAD. `supersedes:` points at `plans/implemented/work/2026-04-20-managed-agent-dashboard-tab.md`. | DoD: file in `plans/implemented/work/`; `supersedes:` populated. <!-- orianna: ok -->
- [ ] **T.D.7** — Run Grep sweep + attach zero-hit evidence to phase-D PR. kind: chore | estimate_minutes: 20 | blocked_by: T.D.1, T.D.2b, T.D.3, T.D.4, T.D.5 | files: none (verification-only) | detail: Grep `managedSessionId`, `create_managed_session`, `setup_agent`, `MANAGED_`, `demo-studio-mcp` across S1 workspace. All five must be 0 outside the two retirement ADRs' historical citations. Ship-gate §9. | DoD: zero hits attested in PR body; any hit blocks phase E. <!-- orianna: ok -->

Phase D exit: S1 boots with neither MCP env nor managed-agent env set; all tests green. Gates phase E.

### Phase E — E2E smoke v2

Xayah's test plan authoritative for assertions; tasks below are implementation hooks.
Anchor: parent §"Test plan" (8 scenarios) + §8 phase E.

- [ ] **T.E.1** — Finalize Xayah's test-plan integration. kind: coord | estimate_minutes: 30 | blocked_by: T.C.2b, T.D.7 | files: Xayah's test-plan file (link when authored) | detail: Confirm Xayah's file covers parent "Test plan" 8 scenarios + 4 unit/xfail items. Resolve overlap with xfail tests authored in phases A/B/C (T.A.1, T.A.5a-f, T.A.7a-c, T.B.1a-b, T.B.3, T.B.5a-b, T.B.7, T.C.1a-b, T.C.3). Hand queue to Vi. | DoD: Xayah's file enumerates all test IDs mapped to T.* IDs. <!-- orianna: ok -->
- [ ] **T.E.2a** — Implement E2E scenarios 1–2 (empty-session + set_config). kind: test | estimate_minutes: 60 | blocked_by: T.E.1 | files: `company-os/tools/demo-studio-v3/tests/e2e/` (the Playwright suite location) | detail: Scenario 1: Slack slash → S1 creates session with `initialContext={}`; browser opens; vanilla agent first-turn greeting. Scenario 2: user "set brand Acme" → `tool_use: set_config` → S2 reflects within 2 s. Parent "Test plan" 1, 2. Video + screenshots per Rule 16. | DoD: 2 scenarios green on staging. <!-- orianna: ok -->
- [ ] **T.E.2b** — Implement E2E scenarios 3–4 (preview iframe + fullview). kind: test | estimate_minutes: 45 | blocked_by: T.E.2a | files: `company-os/tools/demo-studio-v3/tests/e2e/` | detail: Scenario 3: after ≥1 config write, iframe src resolves to S5. Scenario 4: fullview button opens S5 in new tab. Parent "Test plan" 3, 4. | DoD: 2 scenarios green. <!-- orianna: ok -->
- [ ] **T.E.2c** — Implement E2E scenarios 5–6 (build cold + verification pass). kind: test | estimate_minutes: 60 | blocked_by: T.E.2a | files: `company-os/tools/demo-studio-v3/tests/e2e/` | detail: Scenario 5: "build it" → `tool_use: trigger_factory` → S3 `projectId` → SSE build events → verification. Scenario 6: `verificationStatus=passed` surfaces in UI. Parent "Test plan" 5, 6. | DoD: 2 scenarios green. <!-- orianna: ok -->
- [ ] **T.E.2d** — Implement E2E scenarios 7–8 (warm iterate + verify-fail loop). kind: test | estimate_minutes: 60 | blocked_by: T.E.2c | files: `company-os/tools/demo-studio-v3/tests/e2e/` | detail: Scenario 7: same `projectId` reused across second build. Scenario 8: verification fail → iterate → pass, full loop driven by tool-use chain. Parent "Test plan" 7, 8. | DoD: 2 scenarios green. <!-- orianna: ok -->
- [ ] **T.E.2e** — Record full 8-scenario back-to-back run + attach QA report. kind: test | estimate_minutes: 45 | blocked_by: T.E.2a, T.E.2b, T.E.2c, T.E.2d | files: `assessments/qa-reports/2026-04-XX-demo-studio-v3-vanilla-api-smoke-v2.md` (new) | detail: Run all 8 scenarios back-to-back in a single recorded session. Video + screenshots stored under `assessments/qa-reports/`. QA report links video, screenshots, and one row per scenario. PR body linker per Rule 16. | DoD: report linked; all 8 green in one contiguous recording. <!-- orianna: ok -->
- [ ] **T.E.3** — Unit+xfail coverage gap-fill per Xayah. kind: test | estimate_minutes: 45 | blocked_by: T.E.1 | files: existing test files from phases A/B/C (extend where Xayah flags) | detail: Gap-fill only. Expected gaps are none (T.A.1, T.A.5a-f, T.A.7a-c, T.B.1a-b already cover the 4 parent "Test plan" tail items). If Xayah identifies none, close as no-op with commit body note. | DoD: Xayah signs off that parent "Test plan" unit+xfail coverage is complete. <!-- orianna: ok -->

Phase E exit: 8/8 Playwright scenarios green back-to-back in a single recorded staging run. Gates phase F.

### Phase F — Flag flip / ship gate

No feature flag; direct cutover.
Anchor: parent §9.

- [ ] **T.F.1** — Walk parent §9 ship-gate checklist with Duong. kind: coord | estimate_minutes: 30 | blocked_by: T.E.2e, T.E.3, T.D.6a, T.D.6b, T.D.7 | files: parent plan §9 (review only) | detail: Tick all 8 §9 checkboxes incl. Akali UI regression (Rule 16) and MAL+MAD retirement ADRs merged. Sign-off captured. | DoD: §9 check-state recorded in cutover PR body. <!-- orianna: ok -->
- [ ] **T.F.2** — Deploy vanilla-api build to prod via release-please / `ops:` pipeline. kind: chore | estimate_minutes: 45 | blocked_by: T.F.1 | files: Cloud Run revision config, `company-os/tools/demo-studio-v3/deploy.sh` | detail: Heimerdinger advises; Ekko executes. Commit-prefix `ops:` per Rule 5 since infra/deploy is touched. Prior Cloud Run revision retained for rollback per parent §9 final note. | DoD: new revision `Ready: True`; traffic routed; prior revision retained. <!-- orianna: ok -->
- [ ] **T.F.3** — Run prod smoke scenarios 1, 2, 5, 6 within 15 min of deploy. kind: test | estimate_minutes: 30 | blocked_by: T.F.2 | files: Heimerdinger prod smoke runbook | detail: Execute parent §9 prod smoke. Rule 17 auto-rollback on failure via `scripts/deploy/rollback.sh`. | DoD: 4/4 prod scenarios green OR auto-rollback triggered and completed. <!-- orianna: ok -->
- [ ] **T.F.4** — Delete `demo-studio-mcp` Cloud Run service + DNS. kind: chore | estimate_minutes: 30 | blocked_by: T.F.3 | files: GCP Cloud Run service `demo-studio-mcp`; DNS record; secret manager | detail: After prod smoke green, delete Cloud Run service, remove DNS record, delete `DEMO_STUDIO_MCP_URL` from prod secret manager. Commit-prefix `ops:`. | DoD: `gcloud run services list` no longer shows `demo-studio-mcp`; DNS NXDOMAIN; secret gone. <!-- orianna: ok -->

Phase F exit: prod cutover complete; prior revision retained for a 24-hour rollback window; MCP service deleted; parent §9 fully green.

## Task count summary

| Phase | Tasks | Notes |
|---|---|---|
| A | 21 | Split to respect 60-min cap; 12 xfail, 9 feat/refactor |
| B | 11 | 6 xfail, 5 feat |
| C | 6 | T.C.4 conditional |
| D | 9 | Mechanical deletes; parallel with A/B/C; blocks E |
| E | 7 | 8 E2E scenarios split into 2+2+2+2 + recording task + coord + unit gap-fill |
| F | 4 | Ship-gate coord + deploy + prod smoke + MCP-service delete |
| **Total** | **58** | Pre-split count was ~36; split to honor §D4 60-min cap |

## Open questions raised during decomposition

- **OQ-A1** — T.A.9: does the work workspace have a declarative Firestore index config mechanism, or are indexes managed via gcloud ad-hoc? Default: deferred to phase F deploy (T.F.2).
- **OQ-B1** — T.B.6 TS MCP `server.ts` error-string inventory: executor needs exact strings before implementation. Recommendation: Sona pre-flights a grep pass on `server.ts` to produce the inventory. <!-- orianna: ok -->
- **OQ-C1** — T.C.4 conditional on T.C.3 outcome. If T.C.3 passes after T.C.2b lands, T.C.4 is skipped.
- **OQ-D1** — T.D.5 archive-vs-delete on `demo-studio-mcp/`: parent §4 says delete or archive "per team convention". Convention not documented. Default: delete. <!-- orianna: ok -->
- **OQ-D2** — T.D.3 Firestore `lastActivityAt` field backfill: parent §7 greenfield migration implies no backfill needed; defer to D executor.
- **OQ-E1** — T.E.2a-e individual estimates are planner guesses; Vi may refine after Xayah's file lands.
- **OQ-F1** — Akali's UI regression pass (Rule 16) is listed in parent §9 but no task here assigns it. Akali named in parent §12; Evelynn routes when phase E completes.

## Parent-plan §10 open questions the breakdown depended on

- **Q1 conversation persistence** — assumed **(a) subcollection**; drove T.A.1, T.A.2a-d, T.A.9. If Duong flips to (b) packed-blob, T.A.2a rewrites and T.A.9 disappears.
- **Q2 system-prompt storage** — assumed **(a) Python constant**; drove T.A.3, T.A.4. Flip to (b) Firestore singleton adds ~2 tasks (xfail + impl for cache + SIGHUP reload).
- **Q3 tool-result size overflow** — assumed **(a) truncate 900 KB**; folded into T.B.4/T.B.6/T.B.8 as ~10-line guards, no dedicated task. Flip to (b) GCS overflow adds ~2 tasks.
- **Q4 integration-branch treatment** — assumed **(a) revert on `integration/demo-studio-v3-waves-1-4`**; drove phase-D blocking. Flip to (b) abandon-branch changes branch mechanics; task count ~same. <!-- orianna: ok -->
- **Q5 observability** — assumed **(a) structured logs**; folded into T.A.8a-c (~2 log-line additions), no dedicated task.
- **Q6 agent-health surface** — assumed **(b) remove MAD tab entirely**; drove T.D.2a-b. Flip to (a) "Recent Turns" tab adds ~3 tasks (xfail + UI + route).

---

## Test plan (Xayah — inlined from sibling -tests.md per D1A)


# Test Plan — Demo Studio v3 Vanilla Messages API Ship (Option B)

Companion test plan for `plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md` (Swain). Complex-track; authored by Xayah. <!-- orianna: ok -->

**Scope note on bare-path tokens:** this plan references backtick tokens that resolve against the `missmp/company-os` work checkout, not strawberry-agents. Every such line below carries an explicit `<!-- orianna: ok -->` suppressor per the repo-structure linter's per-line rule. Prospective test-file paths (e.g. `test_conversation_store.py`, `test_tool_dispatch.py`, `vanilla_smoke.spec.ts`, `tests/fixtures/mcp_error_strings.json`) will be created by the test implementer after promotion. <!-- orianna: ok -->

**Sibling-file vs inline-body tension:** Xayah's default protocol is to inline test plans into the parent ADR body. Duong's explicit directive for this task overrides that default and requests this sibling file. Orianna's sibling-check gate may block promotion; Sona must reconcile before `plan-promote.sh` runs. <!-- orianna: ok -->

## 0. Ground rules

- **Author role:** Xayah (complex-track test planner). This file is the test matrix — not test code. Rakan authors the unit + integration + fault-injection tests per row; Vi authors the E2E Playwright spec under Caitlyn and Xayah direction per §12 of the parent. <!-- orianna: ok -->
- **Rule 12 gating:** every row with a Rule-12-pairing field MUST be committed as an xfail test on the implementer's branch before the corresponding implementation commit. The `tdd-gate.yml` CI check enforces per-branch ordering. <!-- orianna: ok -->
- **Rule 13 gating:** rows marked `regression-guard` cover behavior already considered part of the merged surface of a preceding phase; they land alongside any bug fix that disturbs that surface. <!-- orianna: ok -->
- **Rule 15 + 16 gating:** Phase E rows are the gated scenarios for `e2e.yml`; UI-touching rows additionally require Akali's QA pass per Rule 16. <!-- orianna: ok -->
- **No silent hangs:** every fault-injection row asserts the failure surfaces as an SSE `error` event within a bounded wall-clock window. A timeout that produces no event is an automatic fail, distinct from an error event whose content is wrong. <!-- orianna: ok -->
- **Fixtures:** unit/integration fixtures under `tests/fixtures/`; Playwright fixtures under `tests/e2e/fixtures/`. Both are prospective paths in the work checkout. <!-- orianna: ok -->
- **Test count:** 54 rows total across phases A–F plus cross-phase fault-injection and regression-guard rows. <!-- orianna: ok -->

## 1. Phase A — Agent-proxy rewrite + conversation persistence

Invariants under test: <!-- orianna: ok -->

- Conversations are append-only; `seq` is monotonic per session and gapless. <!-- orianna: ok -->
- `ConversationStore.load(sid)` returns messages in `seq` order regardless of Firestore server-time skew. <!-- orianna: ok -->
- `ConversationStore` is the single boundary — no other module reads/writes the subcollection. <!-- orianna: ok -->
- `agent_proxy.run_turn` terminates on `end_turn`, loops on `tool_use`, raises on unexpected stop reasons, and respects `MAX_TURNS`. <!-- orianna: ok -->

| Test ID | Scope | Invariant | Setup | Assertion | Rule 12 pairing | Gate | Est (min) |
|---|---|---|---|---|---|---|---|
| TS.A.1 | unit | ConversationStore.append assigns monotonic gapless seq starting at 0. | Firestore emulator; empty subcollection. | Append 5 messages; collection docs have seq=0..4 with no gaps and createdAt set. | T.A.conversation-store-append | unit, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.A.2 | unit | ConversationStore.load orders strictly by seq, not server timestamp. | Emulator; seed 5 docs with seq order 3,0,4,1,2 and createdAt times in a different order. | load() returns messages in seq ascending regardless of timestamp skew. | T.A.conversation-store-load | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.A.3 | unit | ConversationStore.load_since(sid, seq=k) returns only messages with seq greater than k, preserving order. | Emulator; seed 10 messages. | load_since(sid,4) returns exactly seq 5..9. | T.A.conversation-store-replay | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.A.4 | unit | append is idempotent on a client-supplied clientMessageId — retrying the same message does not create a duplicate seq. | Emulator; append once, retry with same clientMessageId. | Only one doc exists; returned seq matches first call. | T.A.conversation-store-idempotency | unit, tdd-gate.yml | 40 | <!-- orianna: ok -->
| TS.A.5 | unit | ConversationStore.truncate_for_model drops oldest non-system messages until token budget fits, preserves last user turn. | Fake 60k-token history; call truncate_for_model(msgs, max_tokens=32000). | Returned list under 32k tokens; last user message retained; no tool_use without paired tool_result. | T.A.conversation-store-truncate | unit, tdd-gate.yml | 45 | <!-- orianna: ok -->
| TS.A.6 | unit | Concurrent append calls against the same session produce distinct sequential seq values (no duplicates, no skips). | Emulator; 10 parallel append tasks. | All 10 complete; set of written seq values equals 0..9. | T.A.conversation-store-concurrency | unit, tdd-gate.yml | 45 | <!-- orianna: ok -->
| TS.A.7 | unit | agent_proxy.run_turn exits on stop_reason end_turn after a single streamed assistant message. | Mock messages.stream yielding one text block + message_stop with stop_reason end_turn. | run_turn returns; store has exactly 2 messages; no tool dispatch invoked. | T.A.agent-proxy-end-turn | unit, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.A.8 | unit | agent_proxy.run_turn executes the tool-use branch once, then continues until end_turn. | Mock stream returning tool_use set_config first, then end_turn second. | Dispatch called exactly once with set_config; store has 4 messages. | T.A.agent-proxy-tool-use-then-end | unit, tdd-gate.yml | 40 | <!-- orianna: ok -->
| TS.A.9 | unit | agent_proxy.run_turn hard-caps at MAX_TURNS and raises MaxTurnsExceeded rather than looping forever. | Mock stream always returns tool_use; MAX_TURNS=3. | After 3 iterations MaxTurnsExceeded raises; SSE sink received error event with code max_turns_exceeded. | T.A.agent-proxy-max-turns | unit, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.A.10 | unit | Unexpected stop_reason raises UnexpectedStopReason and emits an error event. | Mock stream with stop_reason pause_turn. | Raises; SSE error event with code unexpected_stop_reason. | T.A.agent-proxy-unexpected-stop | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.A.11 | integration | Boundary invariant: no module outside conversation_store module touches the subcollection. | Grep in CI over demo-studio-v3 source excluding conversation_store and its tests. | Match count is 0 for the subcollection path and Firestore writes into it. | regression-guard (SE boundary invariant extended to conversations subcollection) | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.A.12 | integration | End-to-end message round-trip: run_turn invoked twice in sequence sees the first turn's messages on the second call. | Firestore emulator + mock Anthropic stream returning text only. | Second run_turn receives messages containing first user+assistant exchange. | T.A.agent-proxy-conversation-load | integration, tdd-gate.yml | 45 | <!-- orianna: ok -->
| TS.A.13 | unit | System-prompt constant is passed through verbatim on every messages.stream call (Q2 pick a). | Patch messages.stream spy; run one turn. | Captured kwargs contain system=SYSTEM_PROMPT. | T.A.agent-proxy-system-prompt | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->

Phase A subtotal: 13 rows (12 new + 1 regression-guard).

## 2. Phase B — Tool-dispatch registry (all five tools)

Invariants under test: <!-- orianna: ok -->

- Every tool_use.name the model can emit has either a registered handler or is a known Anthropic-hosted built-in (web_search). <!-- orianna: ok -->
- Unknown tools surface as tool_result with is_error=true; the loop does not crash. <!-- orianna: ok -->
- Each handler wraps its backend client (S2/S3) with error mapping that preserves the TS MCP server error strings. <!-- orianna: ok -->
- Pure tools are idempotent in the sense of producing identical outputs for identical inputs; side-effecting tools (set_config, trigger_factory) surface duplicates to the caller rather than silently deduplicating. <!-- orianna: ok -->

| Test ID | Scope | Invariant | Setup | Assertion | Rule 12 pairing | Gate | Est (min) |
|---|---|---|---|---|---|---|---|
| TS.B.1 | unit | Registry exports exactly 5 entries with the names/types declared in parent §3.4. | Import module. | Names set equals get_schema, get_config, set_config, trigger_factory, web_search; web_search has type web_search_20241022 and no HANDLERS entry; other four have handler entries. | T.B.tool-dispatch-registry-shape | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.B.2 | unit | dispatch(get_schema,...) proxies to fetch_schema and returns the schema dict. | Mock fetch_schema returns a schema dict. | Handler returns that dict; fetch_schema called once with session context. | T.B.handler-get-schema | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.B.3 | unit | dispatch(get_config,...) proxies to fetch_config(session_id) and wraps result. | Mock. | Backend called exactly once with session id; return value wrapped per parent §5.2. | T.B.handler-get-config | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.B.4 | unit | dispatch(set_config,...) proxies to patch_config(session_id, path, value) and returns success envelope. | Mock patch_config returns ok envelope. | Backend called with correct args; envelope passed through. | T.B.handler-set-config | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.B.5 | unit | dispatch(trigger_factory,...) proxies to trigger_build(session_id); returns projectId. | Mock returns projectId. | trigger_build called once; projectId surfaces in result. | T.B.handler-trigger-factory | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.B.6 | unit | Unknown tool_use.name returns a tool_result with is_error=true and UnknownToolError payload; no exception escapes. | Dispatch nonexistent tool name. | Returned dict has is_error=true, error code unknown_tool, and includes the offending name; no raise. | T.B.handler-unknown-tool | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.B.7 | unit | Backend error mapping: S2 404 NotFound maps to exact user-facing string from TS MCP NotFound branch. | Mock raises NotFoundError. | String byte-identical to captured TS MCP snapshot. | T.B.error-map-not-found | unit, tdd-gate.yml | 25 | <!-- orianna: ok -->
| TS.B.8 | unit | Backend error mapping: S2 401 Unauthorized maps to exact TS MCP Unauthorized string. | Mock raises UnauthorizedError. | Byte-identical snapshot. | T.B.error-map-unauthorized | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.B.9 | unit | Backend error mapping: S2 503 ServiceUnavailable maps to exact TS MCP ServiceUnavailable string. | Mock raises ServiceUnavailableError. | Byte-identical snapshot. | T.B.error-map-service-unavailable | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.B.10 | unit | Idempotency (pure tool): two sequential get_config calls with identical input produce identical output; handler invoked twice (no dedup). | Mock fetch_config tracks call count. | fetch_config called twice; both results equal. | T.B.idempotency-pure-tool | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.B.11 | unit | Side-effect surfacing: two sequential set_config calls with identical input invoke backend twice; duplicate is NOT silently dropped. | Mock patch_config tracks calls. | 2 invocations; 2 tool_result blocks returned; no dedup. | T.B.side-effect-duplicate-surface | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.B.12 | integration | web_search content blocks stream through without S1 dispatch. | Mock stream yields server_tool_use + web_search_tool_result content-block sequence; HANDLERS has no entry for web_search. | dispatch never called for web_search; translator forwards the blocks to SSE unchanged; no UnknownToolError. | T.B.web-search-passthrough | integration, tdd-gate.yml | 40 | <!-- orianna: ok -->
| TS.B.13 | integration | End-to-end tool round-trip against real S2 (staging config-mgmt): set_config through dispatcher reflects within 2 s. | Staging S2 reachable; ephemeral session; real config_mgmt client. | After dispatch, GET on S2 config path returns the written value within 2 s (poll 200 ms). | T.B.integration-set-config-round-trip | integration, tdd-gate.yml | 60 | <!-- orianna: ok -->
| TS.B.14 | unit | Handler signature contract: every handler accepts (input dict, SessionContext) and returns awaitable dict. | Reflective import of each handler. | inspect.signature matches; return type annotation is awaitable dict. | regression-guard (stable contract for future handlers) | unit | 15 | <!-- orianna: ok -->

Phase B subtotal: 14 rows (13 new + 1 regression-guard).

## 3. Phase C — SSE stream adaptation

Invariants under test: <!-- orianna: ok -->

- Every Messages API streaming event type is mapped to exactly one stable browser-facing event, or explicitly dropped with a documented reason. <!-- orianna: ok -->
- Browser event payload shapes are byte-compatible with the current UI contract (parent §3.5). <!-- orianna: ok -->
- A Messages API stream that ends without message_stop triggers an error SSE event (no silent hang). <!-- orianna: ok -->
- Cancel path: consumer abort produces a cancelled event and no trailing turn_end. <!-- orianna: ok -->

| Test ID | Scope | Invariant | Setup | Assertion | Rule 12 pairing | Gate | Est (min) |
|---|---|---|---|---|---|---|---|
| TS.C.1 | unit | content_block_delta with text maps to text_delta SSE event with text payload. | Feed single delta event to translator. | Emitted SSE event has event name text_delta and data with text field. | T.C.translator-text-delta | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.C.2 | unit | content_block_start of type tool_use maps to tool_use SSE event with name and input once input JSON is complete. | Feed content_block_start tool_use + input_json_delta chunks + content_block_stop. | One tool_use event emitted after content_block_stop with complete input dict. | T.C.translator-tool-use | unit, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.C.3 | unit | Synthetic tool_result from dispatcher maps to tool_result SSE event with name and output_summary. | Call translator.emit_tool_result. | SSE event shape matches spec in parent §3.5. | T.C.translator-tool-result | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.C.4 | unit | message_stop maps to turn_end SSE event with stop_reason and usage. | Feed final message with stop_reason end_turn and usage dict. | turn_end event payload matches. | T.C.translator-turn-end | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.C.5 | unit | All Messages API event types are exhaustively mapped — an unknown event emits a warning log, not an exception, and drops cleanly. | Feed made-up event type ping. | Warning logged with event-type name; no exception; no SSE event emitted. | T.C.translator-unknown-event | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.C.6 | unit | Text-delta coalescing: 10 small deltas within 50 ms may coalesce into fewer SSE events but byte-concatenation of emitted text must equal input text. | Feed 10 deltas totalling a known string. | Concatenated emitted text equals input exactly. | T.C.translator-coalescing | unit, tdd-gate.yml | 25 | <!-- orianna: ok -->
| TS.C.7 | unit | server_tool_use + web_search_tool_result pass-through surfaces via tool_use + tool_result events naming web_search. | Feed Anthropic-hosted web-search streaming shape. | Two SSE events emitted with name web_search; no dispatcher call. | T.C.translator-web-search | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.C.8 | integration | session stream route wires run_turn sink to translator; consumer receives correct ordered events end-to-end. | Mock Anthropic stream + real FastAPI route; HTTP client reads SSE. | Received events in order: 1+ text_delta, optional tool_use+tool_result, final turn_end. | T.C.route-stream-wiring | integration, tdd-gate.yml | 45 | <!-- orianna: ok -->
| TS.C.9 | unit | Stream abort mid-turn emits cancelled event and does NOT emit turn_end. | Start translator; abort underlying stream after 2 text deltas. | Last emitted event is cancelled; no turn_end. | T.C.translator-cancel | unit, tdd-gate.yml | 25 | <!-- orianna: ok -->
| TS.C.10 | integration | Stream that ends without message_stop (connection drop) emits error SSE event within 5 s (no silent hang). | Mock stream iterator raises after 2 deltas, no message_stop. | Within 5 s, error event emitted with code stream_terminated. | T.C.stream-abrupt-end | integration, tdd-gate.yml | 30 | <!-- orianna: ok -->

Phase C subtotal: 10 rows.

## 4. Phase D — Deletion sweep

Phase D is mechanical deletion. Most surface is covered by regression-guard rows in A/B/C. Adds here are grep-sweep verifications and boot-without-removed-env smokes. Thin unit coverage acceptable. <!-- orianna: ok -->

| Test ID | Scope | Invariant | Setup | Assertion | Rule 12 pairing | Gate | Est (min) |
|---|---|---|---|---|---|---|---|
| TS.D.1 | integration | S1 boots with no MCP URL/token env and no MANAGED_* env set. | Launch container with explicitly unset envs. | healthz returns 200 within 10 s; startup log contains no KeyError or SettingsError. | T.D.boot-without-managed-env | integration, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.D.2 | integration | Grep sweep: managedSessionId, create_managed_session, setup_agent, MANAGED_AGENT_DASHBOARD return zero hits across demo-studio-v3. | CI grep. | Each pattern's match count is 0 (excluding retirement ADRs). | T.D.grep-sweep-managed-refs | unit, tdd-gate.yml | 15 | <!-- orianna: ok -->
| TS.D.3 | integration | Former managed-agents dashboard routes return 404 (removed), not 500. | HTTP GET each former route. | All return 404. | T.D.managed-agents-routes-gone | integration | 20 | <!-- orianna: ok -->
| TS.D.4 | integration | demo-studio-mcp Cloud Run service absent from staging project service list. | gcloud run services list. | No row with name demo-studio-mcp. | T.D.mcp-service-deleted | integration | 15 | <!-- orianna: ok -->
| TS.D.5 | unit | session_store.transition_status no longer calls the terminal-transition hook introduced by MAL. | Spy on hook; transition a session to completed. | Hook not imported; transition succeeds; no managedSessionId field read. | regression-guard (SE invariant still holds) | unit, tdd-gate.yml | 20 | <!-- orianna: ok -->
| TS.D.6 | unit | env.example contains no MANAGED_* or DEMO_STUDIO_MCP_* keys. | Parse file. | Key-set intersection with forbidden prefixes is empty. | T.D.env-example-clean | unit, tdd-gate.yml | 10 | <!-- orianna: ok -->

Phase D subtotal: 6 rows (5 new + 1 regression-guard).

## 5. Phase E — E2E smoke v2 (Rule 15)

Playwright flow on staging against real S2/S3/S4/S5 + real Anthropic Messages API. Each row maps 1:1 to a parent-plan §Test plan scenario. <!-- orianna: ok -->

| Test ID | Scope | Invariant | Setup | Assertion | Rule 12 pairing | Gate | Est (min) |
|---|---|---|---|---|---|---|---|
| TS.E.1 | E2E | Slack trigger creates session with empty conversation subcollection; first assistant turn produces greeting via vanilla path; no managed-session artefacts. | Trigger Slack slash command against staging. | Browser loads; Firestore session doc has no managedSessionId; empty conversations subcollection; first text_delta arrives within 8 s. | parent §Test plan scenario 1 | e2e.yml, Rule 15 | 60 | <!-- orianna: ok -->
| TS.E.2 | E2E | User asks to set brand; set_config tool-use round-trip; S2 reflects write within 2 s; assistant confirms. | Staging session; type message in chat UI. | SSE shows tool_use set_config + tool_result; S2 config endpoint returns brand=Acme; assistant replies with confirmation text. | parent §Test plan scenario 2 | e2e.yml, Rule 15 | 75 | <!-- orianna: ok -->
| TS.E.3 | E2E | Preview iframe src resolves to S5 and paints after at least one config write. | Scenario 2 prerequisites. | Iframe src host is S5; iframe DOM has painted content within 10 s. | parent §Test plan scenario 3 | e2e.yml, Rule 15 + Rule 16 | 45 | <!-- orianna: ok -->
| TS.E.4 | E2E | Fullview new-tab opens against S5 and loads. | Click fullview button. | New tab URL host is S5; page load event fires; no 4xx/5xx. | parent §Test plan scenario 4 | e2e.yml, Rule 15 + Rule 16 | 30 | <!-- orianna: ok -->
| TS.E.5 | E2E | Build it triggers trigger_factory, S3 returns projectId, build events stream, verification result lands. | Session with configured state; sufficient S3 quota. | SSE shows tool_use trigger_factory; Firestore session projectId populated; verificationStatus transitions through running to terminal within 5 min. | parent §Test plan scenario 5 | e2e.yml, Rule 15 | 90 | <!-- orianna: ok -->
| TS.E.6 | E2E | verificationStatus=passed surfaces in UI. | Scenario 5 completes with passing verification. | UI shows Verification passed text and the pass-color pill. | parent §Test plan scenario 6 | e2e.yml, Rule 15 + Rule 16 | 30 | <!-- orianna: ok -->
| TS.E.7 | E2E | Iterate: same projectId reused across second build (warm path). | Scenario 6 prerequisites; trigger second build via chat. | Second build's Firestore projectId equals first; S3 build endpoint invoked with same id. | parent §Test plan scenario 7 | e2e.yml, Rule 15 | 45 | <!-- orianna: ok -->
| TS.E.8 | E2E | Verification fail, iterate via set_config, then pass. Loop driven by tool-use chain alone. | Inject a known-bad config; then instruct agent to correct. | First verification terminates in failed; after at least one set_config and second trigger_factory, verification reaches passed. | parent §Test plan scenario 8 | e2e.yml, Rule 15 | 90 | <!-- orianna: ok -->
| TS.E.9 | E2E | All 8 scenarios pass back-to-back in a single recorded Playwright run (ship-gate §9). | Sequential execution with video + screenshots. | 8/8 green; QA artifact uploaded under qa-reports; Akali Figma diff attached. | ship-gate aggregate (covers Rule 16) | e2e.yml, Rule 15 + Rule 16 | 30 | <!-- orianna: ok -->

Phase E subtotal: 9 rows.

## 6. Phase F — Ship gate / prod smoke / rollback

Prod-scoped, Rule 17. Smaller subset (scenarios 1, 2, 5, 6) per parent §9. <!-- orianna: ok -->

| Test ID | Scope | Invariant | Setup | Assertion | Rule 12 pairing | Gate | Est (min) |
|---|---|---|---|---|---|---|---|
| TS.F.1 | E2E | Prod smoke executes scenarios 1, 2, 5, 6 within 15 min of deploy; failures auto-trigger rollback. | Deploy to prod; run smoke; assert rollback on induced fail. | Success path: 4/4 green, no rollback; fail path: rollback script invoked, prior revision active, alert posted. | T.F.prod-smoke-auto-rollback | ops CI + Rule 17 | 60 | <!-- orianna: ok -->
| TS.F.2 | integration | Rollback restores prior Cloud Run revision and S1 boots against the prior surface. | Deploy current, rollback, hit healthz. | healthz returns 200 on prior revision within 30 s. | T.F.rollback-cloud-run-revision | ops CI | 20 | <!-- orianna: ok -->
| TS.F.3 | integration | env.example + deploy script linter: no MANAGED_* or DEMO_STUDIO_MCP_* keys present in deployed config. | CI parses rendered deploy-config output. | Intersection with forbidden-prefix set is empty. | T.F.deploy-config-clean | unit | 10 | <!-- orianna: ok -->

Phase F subtotal: 3 rows.

## 7. Fault-injection matrix (cross-phase)

These rows target the one external-dep fault surfaces as bounded error event invariant (parent §11 mitigation bullet). Run against the vanilla agent-proxy with backends mocked at HTTP boundary. Authored by Rakan; no Playwright involvement. <!-- orianna: ok -->

| Test ID | Scope | Invariant | Setup | Assertion | Rule 12 pairing | Gate | Est (min) |
|---|---|---|---|---|---|---|---|
| TS.X.1 | fault-injection | S2 down (connection refused) during set_config handler: tool_result with is_error=true and code service_unavailable; loop continues. | Mock config_mgmt client raises connection refused. | tool_result is_error true; next stream invoked; no crash. | T.X.s2-down-set-config | integration, tdd-gate.yml | 40 | <!-- orianna: ok -->
| TS.X.2 | fault-injection | S3 down during trigger_factory: tool_result error; assistant follow-up turn received; SSE stays open. | Mock factory trigger_build raises. | Error tool_result emitted; SSE continues; eventual turn_end received. | T.X.s3-down-trigger-factory | integration, tdd-gate.yml | 40 | <!-- orianna: ok -->
| TS.X.3 | fault-injection | Anthropic 429 on stream open: retry once with backoff (under 2 s), then surface error SSE event with code rate_limited; no infinite retry. | Mock first stream call raises RateLimitError; second succeeds. | Second attempt runs; first attempt failure in logs; total wall-clock delay under 2.5 s. | T.X.anthropic-429-retry | integration, tdd-gate.yml | 45 | <!-- orianna: ok -->
| TS.X.4 | fault-injection | Anthropic persistent 429 (both attempts): single error SSE event, loop exits, no hang. | Mock both stream calls raise RateLimitError. | One error event emitted within 5 s; run_turn returns. | T.X.anthropic-429-persistent | integration, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.X.5 | fault-injection | Handler raises uncaught Python exception: caught at dispatcher, surfaced as tool_result with is_error=true and code handler_exception; next turn proceeds. | Monkey-patch get_schema handler to raise RuntimeError. | Loop continues; no exception escapes run_turn; SSE shows tool_result error. | T.X.handler-raises | unit, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.X.6 | fault-injection | Anthropic stream hangs mid-turn (no event for 30 s): per-event read timeout fires; error SSE event; run_turn returns. | Mock stream yields 1 delta then blocks indefinitely; set per-event timeout 10 s. | Within 12 s, error event with code stream_idle_timeout emitted; run_turn returns. | T.X.stream-idle-timeout | integration, tdd-gate.yml | 45 | <!-- orianna: ok -->
| TS.X.7 | fault-injection | Firestore write fails on append (quota exhausted): error SSE event + run_turn exit; session doc is not corrupted. | Firestore emulator with forced write-rejection for 1 call. | Error event emitted; post-state subcollection has no partial write; seq sequence unbroken. | T.X.firestore-append-fails | integration, tdd-gate.yml | 40 | <!-- orianna: ok -->
| TS.X.8 | fault-injection | Tool-result payload exceeds 900 KB truncation bound: handler truncates to 900 KB + truncated marker; no Firestore 1 MB rejection. | Mock fetch_schema returns 1.5 MB string. | Written tool_result content length under 900 KB + marker; Firestore doc size under 1 MB; assistant next turn receives the truncated content. | T.X.tool-result-overflow | unit, tdd-gate.yml | 30 | <!-- orianna: ok -->
| TS.X.9 | fault-injection | Cancel request mid-turn aborts the stream, sets a conversation-state cancel marker, emits cancelled SSE, does NOT call sessions.delete (no managed session exists). | Start turn; after 500 ms, hit cancel endpoint. | stream context exited via cancellation; cancelled SSE observed; Firestore session has cancelledAt; no HTTP call to beta/sessions. | T.X.cancel-semantics | integration, tdd-gate.yml | 50 | <!-- orianna: ok -->

Fault-injection subtotal: 9 rows.

## 8. Summary — totals and gate distribution

| Phase | Rows | New (xfail, Rule 12) | Regression-guard | E2E (Rule 15) | Fault-injection |
|---|---:|---:|---:|---:|---:|
| A | 13 | 12 | 1 | 0 | 0 |
| B | 14 | 13 | 1 | 0 | 0 |
| C | 10 | 10 | 0 | 0 | 0 |
| D | 6  | 5  | 1 | 0 | 0 |
| E | 9  | 0 (E2E-authored, not xfail) | 0 | 9 | 0 |
| F | 3  | 3  | 0 | 0 | 0 |
| X (fault-injection cross-phase) | 9 | 9 | 0 | 0 | 9 |
| Total | 54 | 52 | 3 | 9 | 9 |

E-row counts are not xfail-paired because they are authored by Vi at phase E; implementation precedes them. The tdd-gate path applies only to unit/integration rows authored on the same branch as the implementer's work. <!-- orianna: ok -->

Estimated total author effort: ~27 hours across Rakan (phases A/B/C/D/F/X ≈ 23 h) + Vi (phase E ≈ 4 h). Caitlyn owns E-row authorship sequencing per parent §12; Xayah audits the delivered tests post-implementation for coverage gaps. <!-- orianna: ok -->

## 9. Coverage gaps flagged

The following areas have incomplete mock infrastructure or open design questions and may need supplementary planning rounds once Aphelios writes the phase-A task file: <!-- orianna: ok -->

1. TS.X.3 / TS.X.4 — Anthropic 429 retry policy: parent plan does not specify count/backoff/jitter. Assumed 1 retry, ≤2 s backoff. If Viktor picks differently, re-parameterize. Ask Swain/Duong: pin retry policy in a new §5.x of the parent plan. <!-- orianna: ok -->
2. TS.X.6 — Per-event stream-idle timeout: parent does not declare a per-event read timeout. Assumed 10 s per chunk based on SDK defaults. Ask Swain: pin STREAM_IDLE_TIMEOUT_SECONDS in §3.2 or §5.3. <!-- orianna: ok -->
3. TS.X.9 — Cancel endpoint shape: parent alludes to in-process task cancellation + conversation-state marker but does not specify the HTTP surface. Assumed POST cancel route. Ask Viktor at phase A: confirm cancel surface. <!-- orianna: ok -->
4. TS.B.13 (staging round-trip): depends on staging S2 reachability with ephemeral session support. If staging S2 rejects sessions not seeded via Slack, Rakan needs a seeding fixture. Ask Heimerdinger: lightweight S2 session-seed endpoint or full Slack-to-S1 seed required? <!-- orianna: ok -->
5. TS.B.7/8/9 (TS MCP error-string snapshots): requires capturing current TS MCP error strings into a test fixture before MCP is retired. Action for Aphelios phase-B decomp: precursor task snapshot TS MCP error strings to fixture file before any phase-D deletion commit. <!-- orianna: ok -->
6. TS.A.5 (token-budget truncation): assumes tokenizer is available. SDK count_tokens is an API call; a local tokenizer is preferable for unit tests. Ask Viktor: local tokenizer dep, mock count_tokens, or char-based heuristic? <!-- orianna: ok -->
7. E2E scenario 8 (verification-fail injection): requires known-bad config that reliably fails. S4 does not expose a deterministic-fail generator. Ask Heimerdinger or S4 owner: provide canned verification-fail config fixture, or Vi hand-picks brittle input. <!-- orianna: ok -->
8. TS.F.1 (prod rollback on auto-fail): induced-failure testing in prod is risky; must be exercised in prod-adjacent canary, not live prod. Ask Heimerdinger: canary channel or staging-prod-mirror env for rollback exercise? <!-- orianna: ok -->

No gap is a blocker for promoting the parent plan through the Orianna approved gate. All are tractable during phase-A implementation planning. <!-- orianna: ok -->

## 10. Cross-references

- Parent ADR: `plans/proposed/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md` (Swain, 2026-04-21). <!-- orianna: ok -->
- Alternative Option A: `plans/proposed/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md` (Azir). <!-- orianna: ok -->
- Companion in-process-merge (Option A track): `plans/proposed/work/2026-04-21-mcp-inprocess-merge.md` (Karma). <!-- orianna: ok -->
- MAL predecessor (to retire): `plans/implemented/work/2026-04-20-managed-agent-lifecycle.md`. <!-- orianna: ok -->
- MAD predecessor (to retire): `plans/implemented/work/2026-04-20-managed-agent-dashboard-tab.md`. <!-- orianna: ok -->
- Task-file cross-refs (T.A.*, T.B.*, …) resolve against Aphelios's phase-A task ADR, spawned post-signature per parent §8. Until then, Rule-12 pairings cite by descriptive name. <!-- orianna: ok -->

## Tasks

This file is a **test-matrix companion**, not an execution plan, so it carries no implementation tasks of its own. Execution of the matrix below lives on the implementer's task files (Aphelios for complex-track implementation phases; Caitlyn and Xayah drive test-impl sequencing through Rakan and Vi).

- [ ] **T.TEST.1** — Audit delivered phase-A/B/C/D/F unit + integration tests against the matrix in §1–§4, §6–§7 after Rakan lands each phase's xfail batch. kind: audit | estimate_minutes: 45
- [ ] **T.TEST.2** — Audit Vi's Playwright E2E spec (phase E, §5) against the 8 parent-plan scenarios; confirm 8/8 green back-to-back on staging before ship-gate review. kind: audit | estimate_minutes: 30
- [ ] **T.TEST.3** — Re-review coverage-gap open items in §9 after Swain pins the open Anthropic retry + stream-idle-timeout policy in the parent plan; update affected rows in place. kind: audit | estimate_minutes: 30
- [ ] **T.TEST.4** — On any bug discovered during implementation, confirm Rule-13 regression-guard test is added before the fix lands; escalate to Sona if skipped. kind: audit | estimate_minutes: 20
- [ ] **T.TEST.5** — Post-ship, fold any production-incident signatures that were not anticipated in §7 into a new fault-injection row and open a follow-up test-plan revision. kind: audit | estimate_minutes: 30
