---
status: in-progress
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

**D2. Agent mutates a local JSON copy; `set_config` is terminal and whole-snapshot.** The `set_config` tool's `input_schema` flips from `{path, value}` → `{config: object}`. Handler POSTs the whole JSON to S2 `POST /v1/config` with `{sessionId, config}`. S2 auto-versions and returns `{version, config, validation}`. The returned `version` is surfaced in the tool_result + emitted on the SSE status event (D6) so the frontend can invalidate cache, but is NOT mirrored onto the session doc (see BD §BD.B.3 — session doc remains lifecycle-only). No per-field call. No PATCH path exists client-side.

**D3. Seeding at session create.** `POST /session/new` calls S2 `POST /v1/config` with `{sessionId: new_session_id, config: DEFAULT_SEED}` where `DEFAULT_SEED` is a single hardcoded smoke-test dict (initially imported from a new module `seed_config.py`, not a Firestore template library). S1 does NOT mirror the returned config or version. The session doc retains its lifecycle-only shape (see BD §5.1 Rule 2). `configId = sessionId` already serves as the FK for S2 lookups. Rationale: a no-seed path forces every session to start with `get_schema` + 20+ `set_config` calls against a bare doc; seeding gives the agent a realistic baseline and turns GENERATE into edit-not-create. <!-- orianna: ok -- seed_config.py is a prospective new module to be created by this ADR -->

**D4. Drop `get_schema` round-trip from the GENERATE hot path.** With config pre-seeded and injected into context, the agent sees the shape directly. Tool stays registered for STATE-1 clarification use-cases but the SYSTEM_PROMPT "first call MUST be get_schema" rule is removed. `get_config` stays — used in STATE 3 REVIEW for the summary, unchanged semantically.

**D5. Preview reads latest via `GET /v1/config/{sid}`, no version pinning at first.** S1's preview render pulls `GET /v1/config/{sid}` (latest) on demand. Version is NOT on the session doc (BD.B.3) — any caller needing the version queries S2 directly or reads it from the transient SSE status-event payload (D6). Follow-up ADR can pin `?version=N` if race bugs appear.

**D6. Frontend `sessionStorage` cache, configId-keyed, SSE-invalidated.** `static/studio.js` on page boot: `const cached = sessionStorage.getItem('config:' + sessionId + ':' + version)`. On `set_config` completion S1 emits an existing-stream event (reuse the status event shape — no new SSE type in v1) carrying the new version; client invalidates cache and re-fetches via the existing preview proxy. Rejected: new SSE event type (changes SSE schema — defer); per-turn poll (wasteful). <!-- orianna: ok -- cross-repo file in company-os workspace -->

**D7. Validation handling: soft-fail with `?force=true` fallback.** S2 validates on write and can reject. On first POST attempt, S1 sends without `force`. If S2 returns validation errors, S1 logs them + retries with `?force=true` exactly once + surfaces the validation array on the `set_config` tool result so the agent sees which fields failed. Rationale: agent-generated configs will occasionally miss required schema fields; hard-failing abandons the whole snapshot. Alternative (hard-fail always) rejected — no recovery path mid-chat.

**D8. Hotfix first, full flow second.** Ship T-Hotfix (PATCH → POST-snapshot) to unblock prod before the system-block injection work (W1-W3). Hotfix is a minimum surgery: flip `_default_patch_config` to POST the single changed field merged into the last-known config (read via `fetch_config` first), write it back. Ugly but restores a working `set_config` in one PR. System-block injection (W1-W3) then supersedes.

## 3. Architecture Changes

- S1 session schema: unchanged. `_UPDATABLE_FIELDS` is NOT extended. `configId = sessionId` (already present) remains the sole FK to S2. `configVersion`, `seededConfig`, `seedSentAt` are NOT persisted on the session doc (see BD §BD.B.3 / B.4, and session.py:36 docstring invariant).
- S1 `POST /session/new` handler: after `create_session`, call S2 `POST /v1/config` with seed. No session-doc patch follows (seed-POST is fire-and-forget from S1's persistence perspective; S2 owns config state).
- S1 `agent_proxy.run_turn`: accepts `initial_config: dict | None` param; builds multi-block `system` list when present; `stream_ctx = client.messages.stream(..., system=system_blocks, ...)` in both normal and 429-retry branches (§295-300, §330-335).
- S1 tool surface: `set_config` schema flips; `_default_patch_config` deleted; new `_default_snapshot_config(session_id, config)` wraps `config_mgmt_client.snapshot_config` (POST wrapper); `_handle_set_config` rewrites. `get_schema` tool kept but SYSTEM_PROMPT STATE-2 "first call" mandate removed.
- S1 `config_mgmt_client.py`: add `snapshot_config(sid, config, force=False) -> dict` (POST wrapper returning `{version, config, validation}`). Keep `fetch_config`. Delete no existing function (nothing currently POSTs). <!-- orianna: ok -- cross-repo file in company-os workspace -->
- Frontend: configId-keyed sessionStorage in `static/studio.js`; cache invalidate on status-event version change. <!-- orianna: ok -- cross-repo file in company-os workspace -->
- No S2 changes anywhere.

## 4. Tasks

- **T-Hotfix. Unblock prod — PATCH → POST-snapshot shim in `tool_dispatch.py`.** `_default_patch_config` renamed `_default_snapshot_config_shim`: reads latest via `fetch_config(sid)`, merges `{path: value}` via local dotted-path apply, POSTs full snapshot to `/v1/config`. `kind: backend`, `estimate_minutes: 40` <!-- orianna: ok -- cross-repo file in company-os workspace -->
- **W1. S1 seed on session create.** Add `DEFAULT_SEED` to new `seed_config.py`; `POST /session/new` calls S2 POST (seed-POST-only; no session-doc persistence of config state — BD.B.3 invariant preserved). `_UPDATABLE_FIELDS` NOT extended. `kind: backend`, `estimate_minutes: 25` <!-- orianna: ok -- seed_config.py is a prospective new module -->
- **W2. System-block injection.** `run_turn` receives `initial_config` from the caller (chat handler fetches via S2 `GET /v1/config/{sid}` on the first turn of a session — single extra hop, avoids mirroring on session doc per BD.B.3); builds `system` as list; feeds both `messages.stream` call sites (normal + 429 retry). Update SYSTEM_PROMPT: drop "first tool call MUST be `get_schema`" mandate; keep tool descriptions. `kind: backend`, `estimate_minutes: 45` <!-- orianna: ok -- messages.stream is SDK method token -->
- **W3. `set_config` schema flip to whole-JSON + soft-fail validation.** Tool def: `{config: object}`. `_handle_set_config` calls `snapshot_config(sid, config, force=False)` → on validation error retry once with `force=True` + return validation payload in tool_result content. Delete `_default_snapshot_config_shim` from T-Hotfix. `kind: backend`, `estimate_minutes: 50`
- **W4. Frontend sessionStorage cache.** `static/studio.js` adds `config:{sid}:{v}` cache; invalidate on status-event version change; fall back to existing preview proxy fetch. `kind: frontend`, `estimate_minutes: 30` <!-- orianna: ok -- cross-repo file in company-os workspace -->
- **W5. Cleanup & docs.** Remove `_default_patch_config` helper, remove PATCH references from README / ARCHITECTURE.md / SYSTEM_PROMPT error-loop wording. `kind: chore`, `estimate_minutes: 20`

**Total: ~210 min** across 6 waves (T-Hotfix ships first, standalone). Post-amendment (2026-04-23) W1 shrinks from 35 → 25 min (§D3 mirror clause dropped per BD.B.3).

## Test plan

Each wave ships tests. Critical coverage:

- **T-Hotfix:** `_default_snapshot_config_shim` with mock S2 rejecting PATCH + accepting POST — passes. With stale local merge (two racing writes) — documents last-write-wins in docstring.
- **W1:** `POST /session/new` → S2 POST is Bearer-authed with `DS_CONFIG_MGMT_TOKEN`; session doc contains NO `seededConfig`/`configVersion`/`seedSentAt` keys (regression guard matching BD.B.3).
- **W2:** Agent first turn with pre-seeded config makes zero `get_schema`/`get_config` tool calls in the first 3 tool-uses.
- **W3:** `set_config` with malformed config (not a dict) → 400 before S2. Valid config round-trips S2; returned `version` appears in the tool_result and on the SSE status event (not on the session doc — BD.B.3 regression guard). Validation-reject path retries with `force=true` + surfaces errors in tool_result.
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
4. **`configVersion` race safety.** N/A. S1 does not mirror version; S2 restart only affects S2's own in-memory state. Any caller needing version queries S2 directly.
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
4. N/A post-amendment — S1 no longer mirrors version, so no desync surface.
5. No idempotency key for v1.
6. T-Hotfix ships standalone — already in flight as PR #87 (under review; Senna criticals being addressed by Jayce).
7. SSE piggyback on existing status event (D6 stays); new event type deferred.

Promoted-By: Orianna

---

## Tasks-detail

Aphelios breakdown of the W1-W5 wave scope from §4. T-Hotfix is intentionally omitted — already in flight as PR #87 (Jayce addressing Senna criticals C1/C2/C3 out-of-band). All work rooted at the company-os workspace; feature branches cut off the v3 god branch via `scripts/safe-checkout.sh`; every wave merges back into the god branch and waits for green CI before the next wave's impl commits land. <!-- orianna: ok -- company-os workspace root and feat/demo-studio-v3 branch tokens reference cross-repo; safe-checkout.sh lives in strawberry-agents and exists -->

**Load-bearing assumptions (flag for Duong / Evelynn if any slip):**

- **A1.** T-Hotfix (the snapshot-config shim) has landed on the v3 god branch before W3 starts. W3 explicitly deletes the shim; if PR #87 stalls, W3 must be re-sequenced to absorb the hotfix surgery rather than delete it. (No blocker for W1/W2/W4/W5.) <!-- orianna: ok -- T-Hotfix implementation lives in company-os tool_dispatch.py; branch token references cross-repo -->
- **A2.** `config_mgmt_client.fetch_config(sid)` already exists and returns `{config, version, ...}` — the ADR §3 says "Keep `fetch_config`" implying present. Viktor confirms on first read; if absent, add as W1.T2b (≤15 min) before W1.T3. <!-- orianna: ok -- config_mgmt_client.fetch_config is a cross-repo symbol in company-os -->
- **A3.** The existing SSE status event emitter carries a free-form payload dict where we can add `configVersion` without a schema-breaking change (D6 piggyback). If the status event is strongly-typed, W3.T6 becomes ~15 min heavier and W4.T3 needs matching client-side tolerance — flag at implementation time. <!-- orianna: ok -- SSE emitter lives in company-os main.py -->
- **A4.** `DEFAULT_SEED` is a single static dict (OQ-1 resolved: realistic smoke-test, Allianz-like). Swain/Duong will paste the concrete JSON into the new seed-config module during W1.T2 review; Seraphine does not invent schema fields. <!-- orianna: ok -- seed_config.py is a prospective new module in company-os -->
- **A5.** The S2 Bearer token env var on S1 is `DS_CONFIG_MGMT_TOKEN` (probe evidence in §1). W1.T3 uses it verbatim — no rename.
- **A6.** Post-amendment (2026-04-23): N/A. `_UPDATABLE_FIELDS` is NOT modified. Session doc retains its shipped lifecycle-only shape per BD.B.3; no writepath-guard changes in scope for this ADR. <!-- orianna: ok -- session.py and _UPDATABLE_FIELDS are cross-repo tokens in company-os -->

**Parallelism windows (see dispatch diagram at end):**

- **P-α:** W4 (frontend cache) can start its xfail + stub scaffolding as soon as W2 lands, since W4's only backend coupling is the SSE `configVersion` field which W2 does not touch but W3 adds. W4 final wiring (T4/T5) blocks on W3.
- **P-β:** W5 (cleanup & docs) prep tasks (T1 README diff draft, T2 ARCHITECTURE.md diff draft) can run in parallel with W3 impl; the actual deletions (T3) gate on W3 completion.
- **Hard serial:** W1 → W2 (W2 fetches `initial_config` via S2 `GET /v1/config/{sid}`; W1 must have seeded S2 first so the GET returns the seed rather than 404). W2 → W3 (W3's tool-result surface assumes config is in system-block context, not re-fetched). W3 → W5.T3.

### Wave 1 — S1 seed on session create (45 min → 5 sub-tasks; W1.T3 removed per BD.B.3 amendment — numbering preserved)

Depends on: T-Hotfix merged to the v3 god branch (assumption A1, loose — W1 does not touch the tool-dispatch module). <!-- orianna: ok -- v3 god branch and tool-dispatch module are cross-repo tokens -->

- [ ] **W1.T1** — Xfail test: the new-session endpoint calls S2 `POST /v1/config` with `{sessionId: new_sid, config: DEFAULT_SEED}`, Bearer-authed with `DS_CONFIG_MGMT_TOKEN`. Regression guard: session doc contains NO `seededConfig` / `configVersion` / `seedSentAt` keys (BD.B.3 invariant). estimate_minutes: 15. Files: new test module under the v3 tests tree. DoD: three xfail tests committed (happy-path S2 POST, S2-500 fallback, session-doc-keys-absent regression guard); test file imports the not-yet-written `DEFAULT_SEED`; pytest collects all three as xfail; commit message references this plan. <!-- orianna: ok -- demo-studio-sessions is a Firestore collection, session/new is HTTP route, tests live in company-os -->
- [ ] **W1.T2** — Create the new seed-config module exporting `DEFAULT_SEED: dict` (realistic Allianz-like smoke-test per OQ-1). estimate_minutes: 10. Files: new `seed_config` module at the v3 tool root. DoD: module importable; `DEFAULT_SEED` is a plain dict (no callables); field list sourced from Swain/Duong paste during review (see A4); `json.dumps(DEFAULT_SEED)` round-trips without exception. <!-- orianna: ok -- seed_config module lives in company-os v3 workspace -->
- [ ] **W1.T3** — REMOVED (BD.B.3 conflict resolution, 2026-04-23 amendment). `_UPDATABLE_FIELDS` is NOT extended. No session-module change in W1. Keeping a numbered placeholder so downstream references to T1/T2/T4/T5 remain stable. estimate_minutes: 0.
- [ ] **W1.T4** — Wire the new-session handler to call `snapshot_config(sid, DEFAULT_SEED)` after `create_session`. No session-doc patch follows — seed-POST is fire-and-forget from S1's persistence perspective. estimate_minutes: 10. Files: main request-handler module (handler at §1757-1826), config-mgmt client module (add `snapshot_config` if absent). DoD: W1.T1 xfails flip to pass; S2 5xx path logs warning and still returns 200 with session created (soft-fail seeding, not fatal); `snapshot_config` signature is `(sid, config, force=False) -> dict` per §3; no session-doc field-write for config state anywhere in the handler. <!-- orianna: ok -- main handler and config-mgmt client are cross-repo files in company-os -->
- [ ] **W1.T5** — Remove xfail markers from W1.T1 tests; run the full v3 pytest suite locally; push and confirm CI green on branch before merging to the v3 god branch. estimate_minutes: 10. Files: the W1.T1 test module. DoD: zero xfail markers on W1 tests; CI green; wave gate W1-G closed in branch PR description. <!-- orianna: ok -- v3 tests and god-branch token reference cross-repo -->

### Wave 2 — System-block injection (45 min → 7 sub-tasks)

Depends on: W1 merged.

- [ ] **W2.T1** — Xfail test: `run_turn` with `initial_config={"foo": "bar"}` produces a `messages.stream` call whose `system` kwarg is a list of two text blocks: `[{type:"text", text:SYSTEM_PROMPT}, {type:"text", text:<contains "foo">, cache_control:{type:"ephemeral"}}]`. estimate_minutes: 15. Files: new test module for agent-proxy system-block behavior. DoD: xfail test covers both normal branch (§295-300) and 429-retry branch (§330-335) via monkeypatched `client.messages.stream`; commit precedes any agent-proxy modification. <!-- orianna: ok -- agent_proxy.py is a cross-repo file in company-os; messages.stream is an SDK method -->
- [ ] **W2.T2** — Xfail test: first-turn agent with pre-seeded config issues zero `get_schema` / `get_config` tool_use blocks across first 3 tool-uses (Test plan §W2 assertion). estimate_minutes: 10. Files: new test module for no-schema-roundtrip behavior. DoD: xfail test with stubbed Anthropic client returning 3 deterministic tool-uses; assertion is on tool names emitted. <!-- orianna: ok -- tests live in company-os v3 tests tree -->
- [ ] **W2.T3** — Add a `_config_block(cfg: dict) -> dict` helper in the agent-proxy module returning the ephemeral-cached text block per D1. estimate_minutes: 5. Files: agent-proxy module in v3. DoD: helper returns `{"type":"text","text": <json.dumps(cfg, indent=2) prefixed with a fixed "Current config:" header>, "cache_control":{"type":"ephemeral"}}`; unit-tested inline. <!-- orianna: ok -- agent-proxy module is cross-repo in company-os -->
- [ ] **W2.T4** — Extend `run_turn` signature with `initial_config: dict | None = None`; when non-None, build `system = [{"type":"text","text":SYSTEM_PROMPT}, _config_block(initial_config)]` else keep string. estimate_minutes: 5. Files: agent-proxy module (§28-100). DoD: default behaviour unchanged for legacy callers; new branch only taken when config supplied. <!-- orianna: ok -- agent-proxy module is cross-repo in company-os -->
- [ ] **W2.T5** — Thread `system` kwarg into BOTH `client.messages.stream(...)` call sites (normal §295-300 and 429-retry §330-335). estimate_minutes: 5. Files: agent-proxy module. DoD: grep for `messages.stream(` shows both sites pass the same `system` variable; no string-SYSTEM_PROMPT leak remains in either branch when list form is active. <!-- orianna: ok -- agent-proxy module is cross-repo in company-os; messages.stream is SDK method -->
- [ ] **W2.T6** — Update SYSTEM_PROMPT: remove "first tool call MUST be `get_schema`" mandate; keep tool descriptions intact per D4. estimate_minutes: 5. Files: agent-proxy module (SYSTEM_PROMPT constant). DoD: diff removes exactly the one sentence; STATE-1/2/3 structure preserved; Xayah review comment captured in PR if prompt wording becomes contentious. <!-- orianna: ok -- agent-proxy module is cross-repo in company-os -->
- [ ] **W2.T7** — Caller wiring: session-handler code that invokes `run_turn` fetches the current config via `config_mgmt_client.fetch_config(sid)` (S2 `GET /v1/config/{sid}`) on the first turn of a session and passes as `initial_config`. Session doc is NOT read for config state (BD.B.3). Drop xfail markers on W2.T1/T2; CI green on branch. estimate_minutes: 10. Files: main request-handler (chat handler), the two W2.T1/T2 test modules. DoD: zero xfail markers; fetch-on-first-turn only (subsequent turns keep initial_config in closure / session-scoped memory, not re-fetched per turn); W2 gate closed; merged to v3 god branch. <!-- orianna: ok -- main handler and tests are cross-repo in company-os -->

### Wave 3 — `set_config` schema flip + soft-fail validation (50 min → 8 sub-tasks)

Depends on: W2 merged AND T-Hotfix present on branch (deletion target exists).

- [ ] **W3.T1** — Xfail test: `set_config` tool schema is `{config: object}` (no `path`/`value`); a tool_use with `{"path":"a","value":"b"}` is rejected by the dispatch validator with a 400-equivalent tool_result. estimate_minutes: 10. Files: new test module for set-config schema validation. DoD: two xfails (new shape accepts, old shape rejects). <!-- orianna: ok -- tests live in company-os v3 tests tree -->
- [ ] **W3.T2** — Xfail test: valid `{config: {...}}` round-trips via `snapshot_config`; returned `version` surfaces in the tool_result content AND on an emitted SSE status event (D6 piggyback). Regression guard: session doc is NOT patched with `configVersion` / `seededConfig` / `seedSentAt` (BD.B.3). estimate_minutes: 10. Files: new test module for set-config round-trip. DoD: mock S2 returns `{version:2, config:..., validation:{errors:[]}}`; assertions on tool_result `version` + SSE-emit spy + session-doc-unchanged. <!-- orianna: ok -- tests live in company-os v3 tests tree -->
- [ ] **W3.T3** — Xfail test: soft-fail validation — first POST returns `422` / validation-error body; retry with `force=true` returns 200; tool_result content includes the validation array per D7. estimate_minutes: 10. Files: new test module for validation-retry. DoD: xfail asserts exactly one retry (not unbounded); assertion on surfaced validation payload shape. <!-- orianna: ok -- tests live in company-os v3 tests tree -->
- [ ] **W3.T4** — Add/confirm `snapshot_config(sid, config, force=False) -> dict` in the config-mgmt client (POST `/v1/config?force={force}` with Bearer). estimate_minutes: 5. Files: config-mgmt client module. DoD: wrapper returns parsed body dict including `version`, `config`, `validation`; unit test with fake Bearer + httpx mock. <!-- orianna: ok -- config-mgmt client is cross-repo in company-os -->
- [ ] **W3.T5** — Flip `set_config` tool `input_schema` from `{path, value}` → `{config: object}` in the tool registration block. estimate_minutes: 5. Files: tool-dispatch module. DoD: tool def JSONSchema shows single `config` object property (required); description updated to match whole-snapshot semantics. <!-- orianna: ok -- tool_dispatch module is cross-repo in company-os -->
- [ ] **W3.T6** — Rewrite `_handle_set_config` to call `snapshot_config` with `force=False` first, catch validation error, retry once with `force=True`, surface validation array in tool_result content. Emit SSE status event carrying `configVersion` (D6 piggyback — see assumption A3). estimate_minutes: 10. Files: tool-dispatch module, main status-event emitter. DoD: single retry cap enforced; tool_result content is structured JSON with `{version, validation}`; SSE event payload gains `configVersion` key; existing consumers of the status event tolerate the extra key. <!-- orianna: ok -- tool_dispatch and main modules are cross-repo in company-os -->
- [ ] **W3.T7** — Delete `_default_patch_config` (legacy) AND `_default_snapshot_config_shim` (T-Hotfix). estimate_minutes: 5. Files: tool-dispatch module. DoD: grep for both symbol names returns zero hits in the v3 tool tree; call sites replaced by `snapshot_config` direct. <!-- orianna: ok -- tool_dispatch module is cross-repo in company-os -->
- [ ] **W3.T8** — Drop xfail markers on W3.T1/T2/T3; run integration suite; CI green on branch; merge to the v3 god branch. estimate_minutes: 5. Files: the three W3 xfail test modules. DoD: zero xfail markers on W3 tests; wave gate W3-G closed. <!-- orianna: ok -- tests and branch reference cross-repo in company-os -->

### Wave 4 — Frontend sessionStorage cache (30 min → 5 sub-tasks)

Depends on: W2 merged for scaffolding; W3 merged for final wiring (SSE `configVersion` field).

- [ ] **W4.T1** — Xfail browser test: page boot with `sessionStorage['config:{sid}:{v}']` warm → zero network calls to the preview proxy within 5s. estimate_minutes: 10. Files: new Playwright spec in the v3 browser tests tree. DoD: xfail Playwright test asserts network idle on preview-proxy URL pattern; uses fake `sessionId` + `version` seeded into sessionStorage before navigation. <!-- orianna: ok -- browser tests live in company-os v3 tests -->
- [ ] **W4.T2** — Xfail browser test: SSE status event with bumped `configVersion` evicts `config:{sid}:{old_v}` entry and triggers exactly one preview-proxy fetch for the new version. estimate_minutes: 5. Files: new Playwright spec for cache invalidation. DoD: xfail asserts sessionStorage key rotation + single fetch observed. <!-- orianna: ok -- browser tests live in company-os v3 tests -->
- [ ] **W4.T3** — Implement cache read on page boot in the studio.js module: `const cached = sessionStorage.getItem('config:' + sessionId + ':' + version)`; if hit, skip preview-proxy fetch. estimate_minutes: 5. Files: studio.js in the v3 static tree. DoD: cache-miss path unchanged from current fetch behaviour; no synchronous JSON parse on main thread for payloads >100KB (Viktor guard). <!-- orianna: ok -- studio.js is cross-repo in company-os v3 -->
- [ ] **W4.T4** — Wire SSE status-event handler to read `configVersion`, invalidate stale `config:{sid}:*` entries, trigger re-fetch. estimate_minutes: 5. Files: studio.js in v3 static tree. DoD: handler is additive — existing status-event consumers unaffected when `configVersion` field absent (backward-compat). <!-- orianna: ok -- studio.js is cross-repo in company-os v3 -->
- [ ] **W4.T5** — Drop xfail markers on W4.T1/T2; CI green on branch; merge to v3 god branch. estimate_minutes: 5. Files: both W4 browser test specs. DoD: Playwright reports green; W4 gate W4-G closed. <!-- orianna: ok -- branch and tests are cross-repo in company-os -->

### Wave 5 — Cleanup & docs (20 min → 4 sub-tasks)

Depends on: W3 merged (T3 deletions gated); T1/T2 can run in parallel with W3 (P-β).

- [ ] **W5.T1** — README: remove PATCH references; document new agent-owned config flow (seed-at-create, whole-snapshot POST, soft-fail validation). estimate_minutes: 5. Files: the v3 README. DoD: grep for `PATCH` or `patch_config` in the v3 README returns zero matches; new "Config flow (agent-owned)" section present. <!-- orianna: ok -- v3 README lives in company-os -->
- [ ] **W5.T2** — ARCHITECTURE doc: update config-flow diagram/prose; remove PATCH arrow. estimate_minutes: 5. Files: the v3 ARCHITECTURE doc. DoD: sequence diagram shows `POST /v1/config` (whole snapshot) + SSE `configVersion` piggyback; PATCH arrow deleted. <!-- orianna: ok -- v3 ARCHITECTURE doc lives in company-os -->
- [ ] **W5.T3** — SYSTEM_PROMPT final sweep: remove any "error-loop"/"PATCH"/"partial update" wording missed in W2.T6. estimate_minutes: 5. Files: agent-proxy module (SYSTEM_PROMPT). DoD: grep for `patch|PATCH|partial` in SYSTEM_PROMPT constant returns zero matches; Xayah pass on prompt re-read. <!-- orianna: ok -- agent-proxy module is cross-repo in company-os -->
- [ ] **W5.T4** — Final branch merge-up: v3 god branch merged (no rebase per Rule 11) onto main; deployment pipeline kicks off; smoke test per Rule 17 on stg. estimate_minutes: 5. Files: n/a (git operation + CI). DoD: main green; stg smoke green; Cloud Run revision deployed; prod gate awaits Duong go/no-go. <!-- orianna: ok -- v3 god branch is cross-repo on company-os -->

### Dispatch order & parallelism

```
T-Hotfix (PR #87, out-of-band)  ─┐
                                 ▼
W1 ─► W2 ─► W3 ─► W5.T3, W5.T4
              │
              ├──► W4 (starts W2-done; final wiring W3-done)  (P-α)
              │
              └──► W5.T1, W5.T2 (prep in parallel with W3)    (P-β)
```

Peak concurrency (during W3): 3 agents
- Viktor/Jayce on W3 backend impl
- Seraphine on W4 frontend scaffolding (T1-T3, using stubbed SSE)
- Vi/Seraphine on W5.T1/T2 doc prep

### Sub-task count by wave

- W1: 5
- W2: 7
- W3: 8
- W4: 5
- W5: 4
- **Total W1-W5: 29 sub-tasks** (well under the 40-task ceiling)

### Open questions surfaced by decomposition

- **OQ-K1.** Does the config-mgmt client's `fetch_config` already exist on the v3 god branch? (Assumption A2.) If not, add a ≤15-min task inside W1 before T4 (post-amendment: W2.T7 also depends on `fetch_config` for the first-turn GET; adding it in W1 covers both consumers). <!-- orianna: ok -- config-mgmt client and branch are cross-repo in company-os -->
- **OQ-K2.** Is the existing SSE status event payload schema permissive enough to add `configVersion` without breaking existing frontend consumers? (Assumption A3.) If it's strongly-typed (e.g. Pydantic model with `extra=forbid`), W3.T6 grows and W4.T4 needs a compatibility flag.
- **OQ-K3.** `DEFAULT_SEED` concrete JSON body — Swain/Duong paste during W1.T2 review (OQ-1 resolved directionally but actual content TBD).
- **OQ-K4.** Should W4's Playwright tests run under the existing top-level e2e CI workflow (Rule 15) or a separate frontend unit-test harness? Impacts whether W4 merge-gate is the full E2E pipeline (~10 min) or a fast unit lane.

---

## Amendment — 2026-04-23 (BD.B.3 conflict resolution)

**Change.** Dropped `_UPDATABLE_FIELDS` extension (configVersion, seededConfig, seedSentAt). W1 no longer mirrors config state on the S1 session doc.

**Rationale.** Cross-ADR conflict with BD §BD.B.3 (`configVersion` forbidden on session doc). Schema review: `configId = sessionId` already serves as FK; S2 versions are volatile in-memory so a Firestore mirror goes stale on S2 restart; session.py:36 docstring already codifies the invariant.

**Impact.** W1 scope shrinks: seed-POST to S2 on /session/new only, no session-doc patch. W2/W3/W4/W5 unchanged — SSE payload carries version transiently; frontend reads version from SSE event or S2 GET, never from session doc.

**Authored-by.** Swain (ADR amendment, Sona-dispatched, schema review by Sona against deployed S2 rev 00014-2bn + live session.py).

---

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** approved → in-progress
- **Rationale:** Corrective lifecycle flip to reflect that W1 and W2 have already shipped via PRs #91 and #96 (merged); the plan was never moved out of `approved/` at the time implementation began. Plan content is concrete, has a clear owner (Swain), actionable W1-W5 tasks with DoD + estimates, xfail-first test plan satisfying Rule 12, and the prior approval block confirms gating items were resolved. Phase discipline requires the status to match reality — approving the in-progress transition.
