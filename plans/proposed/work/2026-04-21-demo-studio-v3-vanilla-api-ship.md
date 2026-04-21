---
status: proposed
orianna_gate_version: 2
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
- **Three auth surfaces to keep in sync** — Anthropic vault (`MANAGED_VAULT_ID`), MCP bearer (`DEMO_STUDIO_MCP_TOKEN`), S1 operator cookie. `setup_agent.py --force` must rewrite the vault on every URL/token rotation.
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
