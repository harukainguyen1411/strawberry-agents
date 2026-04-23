---
status: approved
complexity: complex
concern: work
owner: swain
created: 2026-04-23
orianna_gate_version: 2
tags:
  - demo-studio
  - config-mgmt
  - agent
  - work
tests_required: true
---

# Agent-owned config flow — S1 adapts to frozen S2 contract

<!-- orianna: ok -- all module tokens (main.py, agent_proxy.py, tool_dispatch.py, config_mgmt_client.py, session.py, static/studio.js) reference files inside the missmp/company-os work workspace under company-os/tools/demo-studio-v3/, not strawberry-agents -->
<!-- orianna: ok -- branch tokens (feat/demo-studio-v3) are git branches on missmp/company-os, not filesystem paths -->
<!-- orianna: ok -- HTTP route tokens (/session/new, /session/{sid}/chat, /v1/config, /v1/config/{session_id}, /v1/schema) are HTTP paths on Cloud Run services, not filesystem paths -->
<!-- orianna: ok -- Firestore field tokens (configId, configVersion, seedSentAt, demo-studio-sessions) are Firestore logical paths/field names, not filesystem -->
<!-- orianna: ok -- env-var tokens (CONFIG_MGMT_URL, CONFIG_MGMT_TOKEN, DS_CONFIG_MGMT_TOKEN, DEFAULT_SEED_CONFIG) are env names, not filesystem -->
<!-- orianna: ok -- deployed-revision tokens (demo-config-mgmt-00014-2bn) are Cloud Run revision identifiers, not filesystem -->

## 1. Context

**Deployed S2 is frozen.** A prior S2 rewrite was reverted yesterday. Revision `demo-config-mgmt-00014-2bn` (image sha256:27c460353d3272c1880e66b4036dbd63c00cb6214a488ae87de1cadfe1e7f427) is the contract S1 must adapt to. This ADR scopes S1 changes only; S2 is out of scope.

**Verified S2 surface (probed via curl + `DS_CONFIG_MGMT_TOKEN`):**

- `GET  /v1/schema` (Bearer) — canonical schema YAML.
- `POST /v1/config?force=bool` (Bearer) — body `{sessionId, config}`. Same `sessionId` on re-POST auto-bumps `version`. Returns `{sessionId, version, config, createdAt, updatedAt, validation}`. Validation runs on write; errors block save unless `?force=true`.
- `GET  /v1/config/{session_id}` (Bearer) — latest (or `?version=N`).
- `GET  /v1/config/{session_id}/versions` (Bearer).
- **NO PATCH.** OpenAPI description: *"No PATCH — every write is a full config snapshot creating a new version."* PATCH returns 405.
- Storage: volatile in-memory dict. CORS: hardcoded to studio origin on `/health` only.

**Current-state bug — `set_config` is broken in prod.** `tools/demo-studio-v3/tool_dispatch.py:100` calls `requests.patch(f"{url}/v1/config/{encoded}", ...)` per field. Every call returns 405 against deployed S2. The entire GENERATE phase silently fails on every write. <!-- orianna: ok -- cross-repo file lives in company-os workspace -->

**Other S1 gaps against the target flow** (verified against `feat/demo-studio-v3`): <!-- orianna: ok -- feat/demo-studio-v3 is a git branch on company-os -->

- `agent_proxy.py:28-100, 295-300, 330-335` — `SYSTEM_PROMPT` is passed directly as a string to `client.messages.stream(..., system=SYSTEM_PROMPT, ...)`. No config JSON in context. Agent relies on `get_schema` round-trip at the start of every GENERATE phase. <!-- orianna: ok -- cross-repo file in company-os workspace; messages.stream is SDK method token -->
- `main.py:1757-1826` — `POST /session/new` stamps `ownerUid`/`ownerEmail` + `configId = session_id` but **never calls S2**. First config write only happens when the agent PATCHes (currently 405s). <!-- orianna: ok -- cross-repo file in company-os workspace -->
- `session.py:57` — session doc writes `configId: session_id`, aligning with S2's sessionId-keyed contract. `configVersion` is not in `_UPDATABLE_FIELDS` (§227-244) and is currently unwritten. <!-- orianna: ok -- cross-repo file in company-os workspace -->
- `static/studio.js` — no `sessionStorage` cache; config is re-read per preview render. <!-- orianna: ok -- cross-repo file in company-os workspace -->

## 2. Decisions

**D1. Config lives in a `system` block, not the prompt body.** On the first turn of a session, `agent_proxy.run_turn` reads the seeded config from S1 session state and builds `system = [{"type": "text", "text": SYSTEM_PROMPT}, {"type": "text", "text": _config_block(cfg), "cache_control": {"type": "ephemeral"}}]`. This keeps the static prefix cache-stable and puts config in the ephemeral tail. Rejected: initial user message (pollutes transcript), tool-result seed (requires a pre-first-turn dummy tool round-trip).

**D2. Agent mutates a local JSON copy; `set_config` is terminal and whole-snapshot.** The `set_config` tool's `input_schema` flips from `{path, value}` → `{config: object}`. Handler POSTs the whole JSON to S2 `POST /v1/config` with `{sessionId, config}`. S2 auto-versions. S1 persists the returned `version` to `demo-studio-sessions/{sid}.configVersion`. No per-field call. No PATCH path exists client-side. <!-- orianna: ok -- demo-studio-sessions/{sid}.configVersion is a Firestore logical field, not filesystem -->

**D3. Seeding at session create.** `POST /session/new` calls S2 `POST /v1/config` with `{sessionId: new_session_id, config: DEFAULT_SEED}` where `DEFAULT_SEED` is a single hardcoded smoke-test dict (initially imported from a new module `seed_config.py`, not a Firestore template library). S1 stores the returned full config + `version: 1` on the session doc (new field `seededConfig: dict`, `configVersion: 1`, `seedSentAt: timestamp`). Rationale: a no-seed path forces every session to start with `get_schema` + 20+ `set_config` calls against a bare doc; seeding gives the agent a realistic baseline and turns GENERATE into edit-not-create. <!-- orianna: ok -- seed_config.py is a prospective new module to be created by this ADR -->

**D4. Drop `get_schema` round-trip from the GENERATE hot path.** With config pre-seeded and injected into context, the agent sees the shape directly. Tool stays registered for STATE-1 clarification use-cases but the SYSTEM_PROMPT "first call MUST be get_schema" rule is removed. `get_config` stays — used in STATE 3 REVIEW for the summary, unchanged semantically.

**D5. Preview reads latest via `GET /v1/config/{sid}`, no version pinning at first.** S1's preview render pulls `GET /v1/config/{sid}` (latest) on demand. `configVersion` on the session doc is informational / for the dashboard, not load-bearing. Follow-up ADR can pin `?version=N` if race bugs appear.

**D6. Frontend `sessionStorage` cache, configId-keyed, SSE-invalidated.** `static/studio.js` on page boot: `const cached = sessionStorage.getItem('config:' + sessionId + ':' + version)`. On `set_config` completion S1 emits an existing-stream event (reuse the status event shape — no new SSE type in v1) carrying the new version; client invalidates cache and re-fetches via the existing preview proxy. Rejected: new SSE event type (changes SSE schema — defer); per-turn poll (wasteful). <!-- orianna: ok -- cross-repo file in company-os workspace -->

**D7. Validation handling: soft-fail with `?force=true` fallback.** S2 validates on write and can reject. On first POST attempt, S1 sends without `force`. If S2 returns validation errors, S1 logs them + retries with `?force=true` exactly once + surfaces the validation array on the `set_config` tool result so the agent sees which fields failed. Rationale: agent-generated configs will occasionally miss required schema fields; hard-failing abandons the whole snapshot. Alternative (hard-fail always) rejected — no recovery path mid-chat.

**D8. Hotfix first, full flow second.** Ship T-Hotfix (PATCH → POST-snapshot) to unblock prod before the system-block injection work (W1-W3). Hotfix is a minimum surgery: flip `_default_patch_config` to POST the single changed field merged into the last-known config (read via `fetch_config` first), write it back. Ugly but restores a working `set_config` in one PR. System-block injection (W1-W3) then supersedes.

## 3. Architecture Changes

- S1 session schema: `_UPDATABLE_FIELDS` gains `configVersion`, `seededConfig`, `seedSentAt`. `configId` stays equal to `sessionId`.
- S1 `POST /session/new` handler: after `create_session`, call S2 `POST /v1/config` with seed; update session doc with returned config + version.
- S1 `agent_proxy.run_turn`: accepts `initial_config: dict | None` param; builds multi-block `system` list when present; `stream_ctx = client.messages.stream(..., system=system_blocks, ...)` in both normal and 429-retry branches (§295-300, §330-335).
- S1 tool surface: `set_config` schema flips; `_default_patch_config` deleted; new `_default_snapshot_config(session_id, config)` wraps `config_mgmt_client.snapshot_config` (POST wrapper); `_handle_set_config` rewrites. `get_schema` tool kept but SYSTEM_PROMPT STATE-2 "first call" mandate removed.
- S1 `config_mgmt_client.py`: add `snapshot_config(sid, config, force=False) -> dict` (POST wrapper returning `{version, config, validation}`). Keep `fetch_config`. Delete no existing function (nothing currently POSTs). <!-- orianna: ok -- cross-repo file in company-os workspace -->
- Frontend: configId-keyed sessionStorage in `static/studio.js`; cache invalidate on status-event version change. <!-- orianna: ok -- cross-repo file in company-os workspace -->
- No S2 changes anywhere.

## 4. Tasks

- **T-Hotfix. Unblock prod — PATCH → POST-snapshot shim in `tool_dispatch.py`.** `_default_patch_config` renamed `_default_snapshot_config_shim`: reads latest via `fetch_config(sid)`, merges `{path: value}` via local dotted-path apply, POSTs full snapshot to `/v1/config`. `kind: backend`, `estimate_minutes: 40` <!-- orianna: ok -- cross-repo file in company-os workspace -->
- **W1. S1 seed on session create.** Add `DEFAULT_SEED` to new `seed_config.py`; `POST /session/new` calls S2 POST; session doc writes `seededConfig` + `configVersion`. `_UPDATABLE_FIELDS` extended. `kind: backend`, `estimate_minutes: 35` <!-- orianna: ok -- seed_config.py is a prospective new module -->
- **W2. System-block injection.** `run_turn` loads `seededConfig` from session; builds `system` as list; feeds both `messages.stream` call sites (normal + 429 retry). Update SYSTEM_PROMPT: drop "first tool call MUST be `get_schema`" mandate; keep tool descriptions. `kind: backend`, `estimate_minutes: 45` <!-- orianna: ok -- messages.stream is SDK method token -->
- **W3. `set_config` schema flip to whole-JSON + soft-fail validation.** Tool def: `{config: object}`. `_handle_set_config` calls `snapshot_config(sid, config, force=False)` → on validation error retry once with `force=True` + return validation payload in tool_result content. Delete `_default_snapshot_config_shim` from T-Hotfix. `kind: backend`, `estimate_minutes: 50`
- **W4. Frontend sessionStorage cache.** `static/studio.js` adds `config:{sid}:{v}` cache; invalidate on status-event version change; fall back to existing preview proxy fetch. `kind: frontend`, `estimate_minutes: 30` <!-- orianna: ok -- cross-repo file in company-os workspace -->
- **W5. Cleanup & docs.** Remove `_default_patch_config` helper, remove PATCH references from README / ARCHITECTURE.md / SYSTEM_PROMPT error-loop wording. `kind: chore`, `estimate_minutes: 20`

**Total: ~220 min** across 6 waves (T-Hotfix ships first, standalone).

## Test plan

Each wave ships tests. Critical coverage:

- **T-Hotfix:** `_default_snapshot_config_shim` with mock S2 rejecting PATCH + accepting POST — passes. With stale local merge (two racing writes) — documents last-write-wins in docstring.
- **W1:** `POST /session/new` → Firestore session doc has `seededConfig`, `configVersion: 1`, `seedSentAt` non-null; S2 call is Bearer-authed.
- **W2:** Agent first turn with pre-seeded config makes zero `get_schema`/`get_config` tool calls in the first 3 tool-uses.
- **W3:** `set_config` with malformed config (not a dict) → 400 before S2. Valid config round-trips S2, session doc `configVersion` advances 1 → 2. Validation-reject path retries with `force=true` + surfaces errors in tool_result.
- **W4:** Frontend boot with warm cache makes zero preview-proxy fetches within 5s. Status-event version bump evicts cache.

## 5. Out of Scope

- Template-selection UX, multi-template libraries. Single `DEFAULT_SEED` only.
- Config diff / rollback UI (though `GET /versions` supports it structurally).
- Migrating pre-cutover sessions — new flow applies to sessions created after deploy.
- S2 Firestore persistence, validation rule changes, CORS changes. **S2 is frozen.**
- v2 (`tools/demo-studio/`). v3 only. <!-- orianna: ok -- cross-repo directory in company-os workspace -->

## 6. Open Questions for Duong

1. **DEFAULT_SEED shape.** Minimal (mostly empty, agent fills in) or realistic smoke-test (Allianz-like, agent edits)? I lean realistic — faster convergence, fewer tool turns.
2. **Full-config round-trip size vs context budget.** Typical config runs ~8-12KB JSON. At 5 turns × 8KB re-read in the ephemeral system block: within context but trims cache-hit rate on the static prefix since ephemeral doesn't affect it. Confirm we accept ephemeral config growing per-turn vs freezing seed for the whole session.
3. **Soft-fail validation behavior.** Retry-with-`force=true` on validation errors (D7) vs surface error + let agent fix and re-call `set_config`? Retry-with-force ships something (agent will fix next turn anyway); hard-fail teaches the agent. I lean retry-with-force for v1, reconsider after prod data.
4. **`configVersion` race safety.** S2 is volatile in-memory; restart drops versions. If S2 restarts mid-session, next POST starts at v1 again and our S1 `configVersion` desyncs. Do we care for v1 (low stakes since storage is ephemeral), or add a post-POST sanity check (`if returned_version < session.configVersion: log_warn`)?
5. **Idempotency / retries.** If S1's POST to S2 times out but S2 actually committed, S1 retry creates v2 with identical content. Acceptable for v1 (volatile dict forgives this), or need client-side idempotency key?
6. **T-Hotfix lifetime.** Ship the shim as a standalone PR merged before W1-W3? Or bundle with W1 in one PR (longer review, slower hotfix)? I lean standalone — prod is broken today.
7. **SSE event shape for cache invalidation (D6).** Piggyback on existing status event carrying `configVersion`, or hold for v2? Piggyback is ~10 lines; new event type is bigger. Confirm piggyback.

---

## Orianna Approval — 2026-04-23

**Decision: APPROVE**

**Fact-check result:** blocks: 0, warns: 0, infos: 0

All load-bearing claims verified:
- Cross-repo file and module path claims pre-annotated with `orianna: ok` markers; exempt from filesystem verification per annotation protocol.
- Cloud Run revision `demo-config-mgmt-00014-2bn`, HTTP routes, Firestore field names, and env-var tokens are vendor/runtime identifiers — exempt per operating discipline.
- PR #87 (`fix: s2 set_config writes via POST /v1/config (deployed S2 rejects PATCH)`) confirmed OPEN on the company-os GitHub repo — matches T-Hotfix description exactly. <!-- orianna: ok -- missmp/company-os is a GitHub repo identifier, not a filesystem path -->
- Target directory for approved work plans confirmed present. <!-- orianna: ok -- plans/approved/work/ is a directory; awk getline on dirs causes i/o error on BSD awk -->
- No speculative claims presented as current-state without qualification.

**Open Questions disposition (Duong accepted Swain recommended defaults):**
1. DEFAULT_SEED — realistic smoke-test accepted.
2. Ephemeral config growth per-turn accepted.
3. Retry-with-`force=true` for v1 (D7 stays).
4. No post-POST sanity check for v1; volatile S2 desync tolerated.
5. No idempotency key for v1.
6. T-Hotfix ships standalone — already in flight as PR #87 (under review; Senna criticals being addressed by Jayce).
7. SSE piggyback on existing status event (D6 stays); new event type deferred.

Promoted-By: Orianna
