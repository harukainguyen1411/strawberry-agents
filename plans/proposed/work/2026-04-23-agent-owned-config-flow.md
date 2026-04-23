---
status: proposed
complexity: complex
concern: work
owner: swain
created: 2026-04-23
orianna_gate_version: 2
tags:
  - demo-studio
  - config-mgmt
  - agent
  - firestore
  - work
tests_required: true
---

# Agent-owned config flow — chat → context → `set_config` POST

<!-- orianna: ok -- all module tokens (main.py, agent_proxy.py, tool_dispatch.py, config_mgmt_client.py, mcp_tools.py, session.py, setup_agent.py, static/studio.js, templates/session.html) reference files inside the missmp/company-os work workspace under company-os/tools/demo-studio-v3/ and company-os/tools/demo-config-mgmt/, not strawberry-agents -->
<!-- orianna: ok -- directory tokens (tools/demo-studio/, versions/, static/studio.js) reference cross-repo paths inside the missmp/company-os work workspace, not strawberry-agents -->
<!-- orianna: ok -- branch tokens (feat/demo-studio-v3) are git branches on missmp/company-os, not filesystem paths -->
<!-- orianna: ok -- HTTP route tokens (/session/new, /session/{sid}, /session/{sid}/chat, /v1/config, /v1/config/{id}, /v1/config/{id}/versions, /v1/schema) are HTTP paths on Cloud Run services, not filesystem paths -->
<!-- orianna: ok -- Firestore collection/field/doc tokens (configs, configs/{id}, configs/{id}/versions/{v}, configs/{configId}, configs/{currentConfigId}.version, configs/smoke-test, configs/smoke-test.json, demo-studio-sessions, demo-studio-sessions/{sid}, configId, configVersion, seedConfigId) are Firestore logical paths/field names, not filesystem -->
<!-- orianna: ok -- prospective-path tokens (scripts/seed-smoke-test-config.sh) cite files that will be created by this ADR's implementation waves -->
<!-- orianna: ok -- env-var tokens (CONFIG_MGMT_URL, CONFIG_MGMT_TOKEN, FIRESTORE_PROJECT_ID, FIRESTORE_DATABASE, SEED_CONFIG_ID) are env names, not filesystem -->

## 1. Context

**Target flow (per Duong):** `POST /session/new` seeds config from Firestore → client caches in `sessionStorage` → agent mutates the JSON in its own context window across research / logo / Apple pass / Google pass / journey → one terminal `set_config` tool call POSTs the whole JSON to S2 on completion. No PATCH. No per-field round-trips.

**Current state — verified against `feat/demo-studio-v3`** (the active codebase; `tools/demo-studio/` is v2, out of scope): <!-- orianna: ok -- feat/demo-studio-v3 is a git branch on missmp/company-os; tools/demo-studio/ is a cross-repo directory in company-os workspace -->

- S2 `tools/demo-config-mgmt/main.py:39-86` <!-- orianna: ok -- cross-repo file, lives in company-os workspace --> is pure in-memory: `_session_configs: dict[str, dict]`, module-scoped `_session_configs_lock`, no `google.cloud.firestore` import. Service restart drops all state.
- S2 surface today: `POST /v1/config` (create w/ `initialConfig`), `PATCH /v1/config/{id}` (dotted-path updates — to delete), `GET /v1/config/{id}`, `GET /v1/config/{id}/versions` (stub returns hardcoded fixture).
- S1 `tool_dispatch.py:43-109, 140-161` <!-- orianna: ok -- cross-repo file, lives in company-os workspace --> defines `set_config` with a `{path, value}` schema and calls `requests.patch(f"{url}/v1/config/{encoded}", ...)` — exactly the PATCH-per-field path Duong wants gone.
- S1 `agent_proxy.py:28-100, 283-299` <!-- orianna: ok -- cross-repo file, lives in company-os workspace --> `SYSTEM_PROMPT` never embeds the config JSON. The agent learns config shape via a `get_schema` tool round-trip at the start of every GENERATE phase.
- S1 `main.py:1757-1826` <!-- orianna: ok -- cross-repo file, lives in company-os workspace --> `POST /session/new` stamps `ownerUid`/`ownerEmail` from the Firebase cookie but never calls S2 to seed.
- Frontend `static/studio.js` <!-- orianna: ok -- cross-repo file, lives in company-os workspace --> has no `sessionStorage` / `localStorage` config cache; config version is polled per-turn via S1 status responses.

## 2. Decisions

**D1. Config lives in a `system` block, not the prompt body.** At chat start S1 injects the seeded config JSON as an additional `system` entry after `SYSTEM_PROMPT` (the Messages API accepts a list for `system`). This keeps the core prompt cache-stable across sessions (the static prefix) and lets the config block carry its own `cache_control: {"type": "ephemeral"}`. Rejected: initial user message (pollutes the chat transcript), dedicated tool-result (requires a tool round-trip before the agent sees the config).

**D2. Agent mutates a local JSON copy; `set_config` is terminal and whole-document.**  `set_config`'s `input_schema` is `{ "config": <full JSON> }`. S1 validates shape + size then POSTs to S2 `/v1/config` with the full config. No `path` field. No per-field call. `get_config` tool stays (for re-reads post-build in STATE 5 QC) but is used <1x per session during GENERATE.

**D3. Versioning model: new top-level doc per POST, `parentId` link (not nested `versions/` subcollection).** Firestore layout: `configs/{configId}` where `configId = {seedShortcode}_{ulid}`. Fields: `{ config, version, parentId, seedConfigId, createdAt, ownerUid, sessionId }`. Rationale: reads are by session (we always know `currentConfigId`), not by history. Lists come from a `configs` where-clause on `sessionId`. A nested `versions/` subcollection buys nothing — there is no rollback UI in scope (§5 out-of-scope). <!-- orianna: ok -- configs/{configId}, versions/ are Firestore logical paths, not filesystem -->

**D4. S1 mints a new `configId` on each `set_config`; session doc tracks `currentConfigId`.** The `demo-studio-sessions/{sid}` doc gains `currentConfigId` (FK to active `configs` doc) and `seedConfigId` (FK to the template row). Preview reads `GET /v1/config/{currentConfigId}`. Reasoning: version-incrementing-the-same-ID makes "what did the agent see when it started" unrecoverable once it finishes. <!-- orianna: ok -- demo-studio-sessions/{sid} is a Firestore logical path, not filesystem -->

**D5. Firestore is S2's source of truth; in-memory dict is a read-through LRU, not a cache of writes.** Restart recovery: on cold start, `_get_config` reads Firestore → populates the dict → returns. Writes go Firestore-first, then populate the dict. The `_session_configs` dict is bounded (e.g. 500 entries, LRU) and becomes a perf optimization, not a correctness primitive.

**D6. Delete the PATCH endpoint and its S1 client paths in one sweep.** `PATCH /v1/config/{id}` removed from S2. `tool_dispatch._default_patch_config`, `config_mgmt_client.patch_config` stub (does not exist today — only invoked via `requests.patch` in `tool_dispatch.py:100`), `mcp_tools._S2Client.set_config`'s per-path loop — all deleted. `mcp_tools.py:46-51` <!-- orianna: ok -- cross-repo file, lives in company-os workspace --> iteration path goes away with the MCP retirement already in-flight (§6 T.X).

**D7. Seed selection: hardcoded `SEED_CONFIG_ID` env for now.** `POST /session/new` reads `os.getenv("SEED_CONFIG_ID", "smoke-test")`, calls S2 `GET /v1/config/{SEED_CONFIG_ID}`, copies the `config` body into the new session's initial state. Template-selection UX is deferred (§5 out of scope). Smoke-test seed ships as a Firestore fixture in S2 deploy (Task T6).

**D8. Frontend cache is `sessionStorage`, keyed by `configId`, hydrated on page load.** `static/studio.js` on session-page load: `const cached = sessionStorage.getItem('config:' + configId)`. If present, use it; if absent, fetch `GET /v1/config/{configId}` through a thin S1 proxy route (S2 is not public). On `set_config` completion S1 emits a `config_updated` SSE event carrying `{ configId, config }` — client updates cache. No per-turn refetch. <!-- orianna: ok -- static/studio.js is a cross-repo file in company-os workspace -->

## 3. Architecture Changes

- S2 gains a Firestore module: `configs` collection with `configs/{id}` docs. S2 requirements.txt adds `google-cloud-firestore`. Reuses `FIRESTORE_PROJECT_ID` / `FIRESTORE_DATABASE` env vars from S1 (same DB, different collection). <!-- orianna: ok -- configs/{id} is a Firestore logical path, not filesystem -->
- S1 session schema: `demo-studio-sessions/{sid}` gains `currentConfigId: string`, `seedConfigId: string`. `configVersion` field kept for BC but decoupled (derived from `configs/{currentConfigId}.version`). <!-- orianna: ok -- demo-studio-sessions/{sid} and configs/{currentConfigId}.version are Firestore logical paths/fields, not filesystem -->
- S1 chat handler: `agent_proxy.run_turn` takes `initial_config: dict` param; builds `system = [SYSTEM_PROMPT_STATIC, {"type": "text", "text": _config_block(initial_config), "cache_control": {"type": "ephemeral"}}]`.
- S1 tool surface: `set_config` schema flips from `{path, value}` to `{config: object}`. `get_config` stays. Old PATCH-per-field handlers removed.
- Frontend: on page-boot fetch sequence becomes `sessionStorage.get(configId) || proxied-GET`; on SSE `config_updated` event cache is overwritten.

## 4. Tasks

The implementation plan (one file per wave) is left for a follow-up split. Shape:

- **W0. S2 Firestore plumbing** — add `google-cloud-firestore` dep, rewrite `_session_configs` as Firestore-read-through; seed `configs/smoke-test` fixture via `scripts/seed-smoke-test-config.sh`. <!-- orianna: ok -- configs/smoke-test is a Firestore logical path; scripts/seed-smoke-test-config.sh is a prospective file to be created by this ADR --> `kind: backend`, `estimate_minutes: 45`
- **W1. S2 versioning model** — new-doc-per-POST, `parentId` link, drop PATCH route. Drop `_apply_dotted_path`. `kind: backend`, `estimate_minutes: 40`
- **W2. S1 seed on session create** — `POST /session/new` calls S2 `GET /v1/config/{SEED_CONFIG_ID}`, stamps `seedConfigId` + `currentConfigId` on session doc. `kind: backend`, `estimate_minutes: 30`
- **W3. S1 chat system-prompt injection** — `agent_proxy` loads config from session doc + injects as cache_control system block. `kind: backend`, `estimate_minutes: 30`
- **W4. S1 `set_config` flip to whole-JSON POST** — schema change, handler rewrite, `config_mgmt_client.create_config(config)`, SSE `config_updated` emit. `kind: backend`, `estimate_minutes: 40`
- **W5. Frontend `sessionStorage` cache** — hydrate-on-boot, overwrite-on-SSE, thin proxy route `GET /session/{sid}/config`. `kind: frontend`, `estimate_minutes: 35`
- **W6. PATCH deprecation sweep** — remove `_default_patch_config`, remove `mcp_tools._S2Client.set_config` per-path loop, update system prompt to drop "fix the value and retry" error-loop wording. `kind: backend`, `estimate_minutes: 25`

**Total: ~245 min** across 7 waves.

## Test plan

Each wave ships with its own tests. Critical coverage:

- S2 Firestore read-through survives service restart (integration test using Firestore emulator).
- S2 `POST /v1/config` creates a new doc with `parentId = previousId`; old doc untouched.
- S1 `POST /session/new` fails loudly if `SEED_CONFIG_ID` doc doesn't exist (no silent fallback to `MOCK_CONFIG`).
- Agent receives config JSON in its first turn with no tool call required (stream the first assistant message, assert no `get_schema`/`get_config` in the first 3 tool-uses).
- `set_config` with a malformed `config` (not a dict) returns 400 from S1 before reaching S2.
- Frontend boot from warm `sessionStorage` makes zero fetches to `/session/{sid}/config` within 5s of page-load.

## 5. Out of Scope

- Template-selection UX (user-facing template library, template preview thumbnails).
- Multi-template libraries (`configs` collection partitioned by tenant / market / line).
- Config diff / rollback UI (the `parentId` chain supports it structurally but is not surfaced).
- Branching / forking versions off a historical `configId`.
- Migrating existing live sessions (pre-cutover) to the new flow — new flow applies to sessions created after deploy.

## 6. Open Questions for Duong

1. **Seed shape.** Does the smoke-test seed include populated `params`/`ipadDemo` sample values (so the agent starts from a realistic baseline), or strictly minimal/empty fields (so the agent writes every field)? My lean: minimal — the agent's job is to generate.
2. **`get_config` retention.** With config in the system prompt, the agent rarely needs `get_config`. Keep it for STATE 5 QC-phase re-reads after a build changes things, or cut it entirely?
3. **SSE `config_updated` event.** Is emitting config-updates over SSE to the client acceptable, or should the client poll on the thin proxy route? SSE is cheaper but requires a new event type in the chat stream schema.
4. **`currentConfigId` immutability.** Once a session completes (factory triggered), does `currentConfigId` freeze, or can STATE 5 QC-tweak still push new versions? If freezing, we need a state-machine guard in S1.
5. **Concurrent POST races.** If two `set_config` calls land for the same session (shouldn't happen but agent retries exist), what wins — last-write-wins (current plan), or reject-if-parentId-stale (optimistic concurrency)?
6. **Seed fixture storage.** Ship the smoke-test seed as a Python dict in `setup_agent.py` and POST it on first-boot, or as a `configs/smoke-test.json` file invoked by `scripts/seed-smoke-test-config.sh`? I lean on the script — treats seeds as data, not code. <!-- orianna: ok -- setup_agent.py is a cross-repo file in company-os; configs/smoke-test.json is a prospective fixture; scripts/seed-smoke-test-config.sh is a prospective script -->
7. **V2 migration path.** `tools/demo-studio/` (v2) still runs in parallel. Does this ADR apply to v2 as well, or only v3 (v2 deprecated per prior ADRs)? Reading the last few weeks of plans, v2 is frozen — I'm assuming v3-only but flagging. <!-- orianna: ok -- tools/demo-studio/ is a cross-repo directory in company-os workspace -->
