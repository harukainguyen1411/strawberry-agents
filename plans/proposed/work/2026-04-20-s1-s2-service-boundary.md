---
status: proposed
orianna_gate_version: 2
complexity: normal
concern: work
owner: azir
created: 2026-04-20
tags:
  - demo-studio
  - service-1
  - service-2
  - architecture
  - boundary
  - work
tests_required: true
orianna_signature_approved: "sha256:e1b224de5be55e4f4db11f727303715ef7a66d050b516bfb186f27982594aa10:2026-04-21T04:22:15Z"
---

# ADR: Demo Studio — S1/S2 Service Boundary (Config-Management Delimitation)

**Date:** 2026-04-20
**Author:** Azir (architecture)
**Scope:** `company-os/tools/demo-studio-v3` (S1) boundary vs `demo-studio-config-mgmt` <!-- orianna: ok — internal service name in missmp/company-os; not a filesystem path --> (S2).
**Companion ADR:** `plans/proposed/work/2026-04-20-session-state-encapsulation.md` (and task file `plans/2026-04-20-session-state-encapsulation-tasks.md` <!-- orianna: ok — future task file in missmp/company-os -->). Both live on `feat/demo-studio-v3` at `d327581`. This ADR **extends** the session-state ADR for most decisions; where §11 resolutions contradict SE (Session dataclass scope, `/session/new` body shape, status response shape, `configVersion` placement), the contradictions are enumerated in the companion amendment file `company-os/plans/2026-04-20-session-state-encapsulation-bd-amendment.md`. <!-- orianna: ok — cross-repo amendment file in missmp/company-os -->

## 1. Context and posture

Duong's stance, adopted verbatim (resolved 2026-04-20 s3):

> "we only care about creation of the config and manage sessions of the managed agent."

Interpreted as S1's scope: (a) host the Anthropic managed agent, (b) track the agent's session lifecycle, (c) forward requests to/from the agent. Nothing else. No config storage, no builds, no previews, no translation.

- **S1 owns session lifecycle only — strictly.** The S1 session document holds: `sessionId`, `createdAt`, `updatedAt`, `phase`, `status`, agent pointer (`managedSessionId`), `factoryRunId`, `projectId`, `outputUrls`, `qcResult`, Slack coordinates, `archivedAt`, events subcollection. **NOT** `brand`, `market`, `languages`, `shortcode`, `configVersion` (absent unless independently justified — see §5.1), `colors`, `logos`, `card`, `params`, `ipadDemo`, `journey`, `tokenUi`. Identity fields (`brand`, `market`, `languages`, `shortcode`) are agent-input — passed in on creation so the managed agent boots with them — but are **not persisted on the session doc**.
- **S2 owns config CRUD.** Schema, full-snapshot `DemoConfig`, version history, validation (structural + cross-field), `tokenUi` overrides, brand/market/languages/shortcode fields, `params`, `colors`, `logos`, `card`, `ipadDemo`, `journey`.
- **S3 (Factory) owns translation.** S3 fetches config from S2 itself per `company-os/tools/demo-factory/api/factory.yaml` <!-- orianna: ok — cross-repo file in missmp/company-os --> line 192 (`required: [sessionId]`). S1 never translates `DemoConfig` → factory params; that family of functions (`map_config_to_factory_params`, `_build_content_from_config`, `prepare_demo_dict`) deletes from S1.
- After this ADR + the session-state ADR land, **S1 has no Firestore writes for config, no config business logic, no factory-param translation, and no identity-field persistence**; anything config-shaped is an HTTP call to S2, anything factory-shaped is a thin `POST /build {sessionId}` to S3.

The session-state ADR enforces the Firestore-side boundary for S1 via a single `session_store.py` <!-- orianna: ok — company-os module name, not a local file --> plus the SE.E grep gate. That gate is scoped to `from google.cloud import firestore`, so it catches "S1 writing config to Firestore" only *if and because* S1 is reading or writing the legacy `config` field via Firestore at all. The grep gate does not flag, e.g., a call site that reads `session["config"]["brand"]` after `session_store.get_session(...)` — that path would quietly carry config through the boundary. This ADR closes that gap by making the `config`/`configVersion`-shaped fields illegal on the S1 session document *at the domain level*, not only at the storage level.

### 1.1 Why now

The session-state ADR's SE.B phase (call-site migration) rewrites every site where `main.py` <!-- orianna: ok — company-os file --> / `factory_bridge*.py` <!-- orianna: ok — company-os file glob --> / `dashboard_service.py` <!-- orianna: ok — company-os file --> / `phase.py` <!-- orianna: ok — company-os file --> read `session.get("config", …)` or write `update_session_field(..., "config", …)`. If we don't settle the S1/S2 boundary first, SE.B is migrating legacy config code through a boundary that is about to disappear — producing two migrations for the same call sites and guaranteeing a rebase storm. This ADR must land **before SE.B.2** (the `main.py` call-site migration) to avoid that waste; it may land in parallel with SE.A (the additive `session_store.py` <!-- orianna: ok — company-os module; see line 38 suppressor --> module), since SE.A is purely additive on the storage surface.

### 1.2 What this ADR is NOT

- **NOT** a redesign of S2. S2's spec (`reference/2-config-mgmt.yaml` <!-- orianna: ok — company-os reference spec; lives at missmp/company-os/reference/ -->) is authoritative; where S1 needs a capability S2 doesn't expose, we flag it as a blocker on the S2 side, not work around it.
- **NOT** a change to the S1 HTTP surface beyond what `reference/1-content-gen.yaml` <!-- orianna: ok — company-os reference spec; lives at missmp/company-os/reference/ --> already prescribes. Session-state ADR §5 and §6.3 already track the spec-drift list; this ADR only adds the items that fall out of config ejection.
- **NOT** a change to the MCP server (`demo-studio-mcp` <!-- orianna: ok — internal MCP server name in missmp/company-os; not a filesystem path -->). The MCP tools (`get_schema`, `get_config`, `set_config`) already target S2 directly; S1 is not in that path and should not become one.
- **NOT** a migration plan for existing `config`-bearing session documents. Section 8 covers the backfill-or-orphan question and hands live-data handling to ops.

## 2. Decision

**Rule 1 (boundary rule at the domain level).** No S1 code path may:
  - read or write `session["config"]` (the embedded config snapshot),
  - validate config structure,
  - translate config to factory params (i.e. the `map_config_to_factory_params` / `_build_content_from_config` / `prepare_demo_dict` family),
  - load a sample/default config,
  - accept a PATCH/PUT on a config-shaped body.

**Rule 2 (integration rule).** Any S1 code that needs config *data* MUST fetch it from S2 via `config_mgmt_client.fetch_config(session_id)` (or a caller-specified version pin) at the moment of use. No caching of the config snapshot on the S1 session document, no "mirror-on-read" pattern. The source of truth is S2; S1 keeps a pointer (`configVersion`) and nothing else.

**Rule 3 (pointer rule).** `configVersion` is **not** carried on the S1 session doc by default. S1 does not POST to S2 at session creation (per OQ-BD-5 resolution (c)); there is no version to mirror at creation time. The first version is created when the agent's first `set_config` MCP call lands on S2. If a downstream path needs to know "which config version did this session use?", it queries S2 (`GET /v1/config/{sessionId}` → `version`) at the moment of use. If, after this ADR lands, a concrete S1-only caller requires `configVersion` on the session doc (e.g. for a pinned-build audit trail that cannot be reconstructed from S2 events), that caller must justify the field explicitly; otherwise the field is absent. The build-reproducibility argument in the old §5.3 no longer applies to S1 because S1 no longer triggers a translated build — S3 fetches the latest from S2 itself per its own spec (§5.3).

**Rule 4 (enforcement).** Extend the SE.E grep gate with two additional patterns:
  - Disallow `session\[?["\']config["\']\]?\s*=` (assignment) and `"config"\s*:` as a Firestore write field inside any file under `tools/demo-studio-v3/` <!-- orianna: ok — grep-gate pattern string; refers to company-os repo not this repo --> other than tests and an explicit migration script.
  - Disallow literal string `insuranceLine` anywhere under `tools/demo-studio-v3/` <!-- orianna: ok — grep-gate pattern string; refers to company-os repo not this repo --> (it's not in the S2 schema; it is the canonical symptom of legacy-config drift).

Gate exceptions are whitelisted by a single `# azir: config-boundary` comment, mirroring the SE.E convention.

## 3. Evidence — enumeration of every S1 config touchpoint

All line numbers are against `feat/demo-studio-v3@d327581` <!-- orianna: ok — git branch@commit ref, not a filesystem path -->. Orianna should fact-check this inventory before the task file is decomposed.

<!-- orianna: ok — all file paths in §3 (tools/demo-studio-v3/session.py, main.py, factory_bridge.py, factory_bridge_v2.py, factory_v2/validate_v2.py, preview.py, config_mgmt_client.py, sample-config.json, dashboard_service.py, phase.py, agent_proxy.py, logo_upload.py, setup_agent.py) are cross-repo files in missmp/company-os; this section is an architectural audit, not a local file inventory -->

### 3.1 `tools/demo-studio-v3/session.py` <!-- orianna: ok — company-os file; all §3 tool paths are in missmp/company-os/tools/demo-studio-v3/ -->
| Line | Function | Shape | Verdict | Notes |
|---|---|---|---|---|
| 42 | `create_session(...)` | writes `"config": initial_context or {}` into the new session doc | **Delete from S1** | Session doc has no business holding a config snapshot. Creation is a bare `{sessionId, status, phase, managedSessionId: null, slack*, factoryVersion, createdAt, updatedAt}` — no `configVersion`, no `config`. The caller does NOT create a first config version on S2 at creation time (per OQ-BD-5 (c)). First version is created when the agent's first `set_config` MCP call lands on S2. See §5.1. |
| 43 | `create_session(...)` | writes `"configVersion": 1` | **Delete from S1** | No `configVersion` on the S1 session doc by default. There is no version to mirror at creation time (S1 does not POST to S2). Once the agent writes the first config via MCP → S2, the version lives on S2. S1 does not need to mirror it (per Rule 3, revised). |
| 118–128 | `list_recent_sessions(...)` | reads `config.brand`, `config.insuranceLine`, `config.market` out of each session doc to compose the result | **Delete from S1** | Strict BD-1: brand/market/languages/shortcode are not on the session doc. Consumers of `/sessions` that want identity fields call S2 directly (N+1 accepted) or the UI does. `list_recent_sessions` returns lifecycle fields only. See §5.5. |
| 133 | `_UPDATABLE_FIELDS` | allowlist includes `eventHistory`, `archivedAt`, `workerJobId`, `projectId`, `factoryRunId`, `outputUrls`, `managedSessionId` — all session-lifecycle-only | **Keep as-is** | None of these are config. Allowlist is already clean. The config-boundary gate from §2 will reject any future PR that tries to add `"config"`, `configVersion`, or config-shaped keys to this set. Also reject `brand`, `market`, `languages`, `shortcode` — those are agent-input, not session-persisted. |

### 3.2 `tools/demo-studio-v3/main.py` <!-- orianna: ok — company-os file -->

| Line | Route / function | Shape | Verdict |
|---|---|---|---|
| 53 | module-level `SAMPLE_CONFIG: dict = {}` | default/sample config carrier | **Delete from S1** |
| 1190 | `create_new_session_ui` | `initial_context = json.loads(json.dumps(SAMPLE_CONFIG))` deep-copy + sets `brand`/`insuranceLine`/`market` | **Delete from S1** |
| 1192 | `create_new_session_ui` | `initial_context["insuranceLine"] = body.insuranceLine` | **Delete from S1** — the `insuranceLine` field is not in S2's `DemoConfig` schema at all |
| 1196–1201 | `create_new_session_ui` | passes `initial_context=initial_context` into `create_session(...)` which persists it as `session["config"]` | **Delete from S1** — replaced by "create bare session, then POST to S2 with the initial config" (§5.1) |
| 1219 | `create_new_session_ui` | `send_message(..., f"Initial context: {json.dumps(initial_context)}")` sends full config into the Managed Agent context | **Refactor** — agent-init metadata only: send the seed identity fields (`brand`, `market`, `languages`, `shortcode`) so the managed agent boots with them. Do NOT send a full `DemoConfig`; the agent resolves via `get_schema` + `get_config` MCP calls. Exact shape of the agent-init message is Kayn's to refine in SE.F.1 follow-up work. |
| 1250–1254 | `create_new_session` (internal/Slack variant) | `seeded_context = SAMPLE_CONFIG deep-copy; seeded_context.update(body.initialContext)` and passes to `create_session(initial_context=seeded_context)` | **Delete from S1** — same treatment as UI variant. No SAMPLE_CONFIG, no initial_context persistence. The internal variant accepts the same identity-field body and boots the agent the same way. |
| 1284 | `create_new_session` | sends `json.dumps(seeded_context)` into Managed Agent | **Refactor** — same as 1219 (identity fields only, as agent-init metadata). |
| 1349 | `session_page` | `session.get("config", {}).get("brand", "New Session")` for HTML `<title>` | **Refactor-to-S2-API-call** — session doc no longer has `brand`. Call `config_mgmt_client.fetch_config(session_id)` on render, fall back to "New Session" on S2 404 (cold session, pre-first-set_config). Single-page-load cost. |
| 1395–1397 | `chat` (lazy managed-session create) | reads `session.get("config", {}).get("brand"/"insuranceLine"/"market")` to build the managed-agent title | **Refactor-to-S2-API-call** — fetch from S2 on the lazy-create path. `insuranceLine` is not in the S2 schema at all (see §3.2 line 1192) and disappears entirely. |
| 1439–1445 | `preview` route + `render_preview(config, config_version)` | reads `session.get("config", {})` and `session.get("configVersion", 0)` and renders Jinja template | **Delete from S1** — preview is S5 (iframe) scope per OQ-BD-3 resolution. S1 does not render previews, does not serve preview routes, does not track `configVersion` for UI pinning. The `/preview` <!-- orianna: ok — HTTP route name, not a filesystem path --> route deletes from S1; any preview concern moves to S5. Note: this route was already flagged for S5 handoff prior to this ADR; BD codifies the handoff. |
| 1461–1472 | `session_status` | reads `session.get("config") or {}` and `logos = config.get("logos") or {}` plus `configVersion` from the session doc | **Refactor** — drop `logos` from the response (per OQ-BD-2 resolution). `configVersion` also drops: not on the session doc by default, and the status response does not need it. Status response shrinks to lifecycle fields only (`status`, `phase`, timestamps, agent pointer, `factoryRunId`, `projectId`, `outputUrls`, `qcResult`). |
| 1987–2001 | `session_history` | reads `cfg = session.get("config") or {}` and `cfg.get("brand", "")` for the summary | **Refactor-to-S2-API-call** — history view fetches the latest config from S2. If version-pinned history is needed, call `GET /v1/config/{sessionId}/versions` (S2) and per-version `GET /v1/config/{sessionId}?version=N`. History is a cold path — N+1 acceptable. |
| 2055–2065 | `list_sessions` | same brand/market/insuranceLine-from-session-doc pattern as `session.list_recent_sessions` | **Delete from S1 (identity-field extraction)** — list response returns lifecycle-only `SessionSummary` rows: `{sessionId, status, phase, createdAt, updatedAt, managedSessionId?, factoryRunId?, projectId?}`. Consumers that want `brand/market/shortcode` call S2 per session (N+1) or fan out client-side. S2 batch-get remains a deferred ask (§6.1). |

### 3.3 `tools/demo-studio-v3/factory_bridge.py` <!-- orianna: ok — company-os file; all §3 sub-section file paths are in missmp/company-os -->

| Line | Code | Shape | Verdict |
|---|---|---|---|
| 33–129 | `map_config_to_factory_params(config)` | 90+ LOC that reads `config.brand`, `config.insuranceLine`, `config.hubspotDealId`, `config.colors.*`, `config.logos.*`, `config.persona`, `config.passFields.*`, `config.journeySteps`, `config.tokenUi`, `config.googleWallet` — entire config → factory params mapping | **Delete from S1** — OQ-BD-6 resolution confirms S3 `/build` takes `{sessionId}` only. S3 fetches config from S2 itself. S1 does no translation. |
| 142–190 | `_build_content_from_config(config, params)` | builds `content` dict that factory modules expect from mapped params | **Delete from S1** — same reason. Second translation layer; belongs in S3 behind its `{sessionId}`-only contract. |
| 202 | `trigger_factory(session_id)` | `session = get_session(session_id)` | **Refactor** — stays; S1 reads its own session for lifecycle purposes (`status`, `factoryVersion`, writing `factoryRunId`). |
| 209 | `trigger_factory` | `config = session.get("config", {})` | **Delete from S1** — S1 does not fetch config before calling S3. Per OQ-BD-6, S1's call to S3 is `POST /build {sessionId}` and S3 fetches from S2 itself. No `config_mgmt_client.fetch_config` on the factory path. |
| 210–211 | `trigger_factory` | `factory_params = map_config_to_factory_params(config); content = _build_content_from_config(config, factory_params)` | **Delete from S1** — factory call becomes a thin `POST /build {sessionId}` (no `configVersion`, no translated payload). S3 handles the rest. |
| 250, 253 | `trigger_factory` | `logos = config.get("logos", {})`, `bg_color = config.get("colors", {}).get("primary", ...)` | **Delete from S1** — no config read on the factory path at all. If S1 needs visual context for, e.g., a Slack notification, fetch from S2 (`config_mgmt_client.fetch_config`) on the notification code path — not the build path. |

### 3.4 `tools/demo-studio-v3/factory_bridge_v2.py` <!-- orianna: ok — company-os file; all §3 sub-section file paths are in missmp/company-os -->

| Line | Code | Shape | Verdict |
|---|---|---|---|
| 35–63 | `prepare_demo_dict(config)` | deep-copy config + default-fill `languages/params/translations/card/journey/demoSteps`, merge persona into params | **Delete from S1** — OQ-BD-6 resolution: S3 takes `{sessionId}` only; all translation deletes from S1. |
| 75 | `trigger_factory_v2(session_id)` | `session = get_session(session_id)` | **Refactor** — keep for lifecycle fields |
| 82 | `trigger_factory_v2` | `config = session.get("config", {})` | **Delete from S1** — no config fetch on factory path (see §3.3 line 209). |
| 97, 109–115 | `validate(config)` via `factory_v2.validate_v2` | local config-schema validation (brand, persona, colors, journey required-field checks) | **Delete from S1** — validation is S2's job per the S2 spec's `POST /v1/config` contract. S1 trusts S2's validation and never runs its own. Delete `validate_v2.py` from S1 outright. |
| 118 | `trigger_factory_v2` | `demo = prepare_demo_dict(config)` | **Delete from S1** |
| 140–143 | `trigger_factory_v2` | `logos = demo.get("logos", {})`, `bg_color = demo.get("colors", {}).get("primary", ...)` | **Delete from S1** |

### 3.5 `tools/demo-studio-v3/factory_v2/validate_v2.py` <!-- orianna: ok — company-os file; all §3 sub-section file paths are in missmp/company-os -->

Entire file (73 LOC). Validates `brand`, `persona.{firstName,lastName}`, `colors.primary`, `journey[*].{name,triggerType,triggerEvent,triggerTiming,changeMessage}`. **Delete from S1.** Validation is S2's contract per `POST /v1/config`.

### 3.6 `tools/demo-studio-v3/preview.py` <!-- orianna: ok — company-os file; all §3 sub-section file paths are in missmp/company-os -->

| Line | Code | Shape | Verdict |
|---|---|---|---|
| 16–22 | `render_preview(config, config_version)` | takes a config dict + version, renders Jinja | **Delete from S1** — preview is S5 scope (iframe) per OQ-BD-3 resolution. S1 does not render previews. Entire `preview.py` file deletes from S1; its owning route (`main.py:1439–1445`) also deletes. |

### 3.7 `tools/demo-studio-v3/config_mgmt_client.py` <!-- orianna: ok — company-os file; all §3 sub-section file paths are in missmp/company-os -->

Entire file (109 LOC) is the S1→S2 HTTP client. Currently **imported only by tests** — runtime code never calls it. Two specific concerns:

| Line | Function | Shape | Verdict |
|---|---|---|---|
| 71–79 | `fetch_schema()` | `GET /v1/schema` — well-aligned with S2 spec `getSchema` | **Keep** — canonical way S1 obtains the schema if needed. |
| 82–91 | `fetch_config(sid)` | `GET /v1/config/{session_id}` — well-aligned with S2 spec `getConfig` | **Keep** — this is the integration path §2 Rule 2 mandates. A `version: int \| None = None` query parameter is available for any caller that wants a pinned version; default latest. No build-path caller (per §5.3, S3 fetches its own config); remaining callers are render/history paths. |
| 94–108 | `patch_config(sid, path, value)` | sends `PATCH /v1/config/{session_id}` with `{updates: [{path, value}]}` | **Delete from S1** — OQ-BD-4 resolution: match S2's contract (no PATCH endpoint). `patch_config` is a phantom against `reference/2-config-mgmt.yaml` <!-- orianna: ok — company-os reference spec --> and is not called at runtime. Delete the function outright. If S2 ever ships PATCH, re-add with the then-specified shape. |

### 3.8 `tools/demo-studio-v3/sample-config.json` <!-- orianna: ok — company-os file; all §3 sub-section file paths are in missmp/company-os -->

105 LOC. Pre-existing "Step 1 cleanup" test (`tests/test_no_local_validation.py:41-47` <!-- orianna: ok — company-os test file -->) already asserts this file must be deleted; Jayce never completed that cleanup. **Delete from S1.** The file is dead.

### 3.9 `tools/demo-studio-v3/dashboard_service.py` <!-- orianna: ok — company-os file; all §3 sub-section file paths are in missmp/company-os -->

No config touches. Dashboard aggregates logs across services (`/logs` endpoints) only. **No change.**

### 3.10 `tools/demo-studio-v3/phase.py` <!-- orianna: ok — company-os file; all §3 sub-section file paths are in missmp/company-os -->

No config touches — only reads/writes `phase` field. `phase` is a session-lifecycle field. **No change.**

### 3.11 `tools/demo-studio-v3/agent_proxy.py` <!-- orianna: ok — company-os file; all §3 sub-section file paths are in missmp/company-os -->

No config touches. **No change.**

### 3.12 `tools/demo-studio-v3/logo_upload.py` <!-- orianna: ok — company-os file; all §3 sub-section file paths are in missmp/company-os -->

Uploads image bytes to Wallet Studio; returns CDN URL. The caller (agent, via `set_config`) is responsible for persisting that URL into the config on S2. S1 itself never writes `logos` to a session doc. **No change.**

### 3.13 `tools/demo-studio-v3/setup_agent.py` <!-- orianna: ok — company-os file; all §3 sub-section file paths are in missmp/company-os -->

System-prompt refers to `set_config`, `get_config`, `get_schema` MCP tools that target S2 directly. Not a config touchpoint in S1 runtime. **No change.**

### 3.14 Summary count (revised post-resolutions)

- **Delete-from-S1 (17):**
  - `session.create_session` embedded `config` write (§3.1 line 42)
  - `session.create_session` `configVersion: 1` write (§3.1 line 43 — previously refactor)
  - `session.list_recent_sessions` identity-field extraction (§3.1 line 118–128 — previously refactor-to-S2)
  - `main.SAMPLE_CONFIG` module-level (§3.2 line 53)
  - `main.create_new_session_ui` sample-config deep-copy + identity seeding (§3.2 line 1190)
  - `main.create_new_session_ui` `insuranceLine` plumbing (§3.2 line 1192)
  - `main.create_new_session_ui` `initial_context` persistence (§3.2 line 1196–1201)
  - `main.create_new_session` (internal) seeded-context persistence (§3.2 line 1250–1254)
  - `main.preview` route + `preview.py::render_preview` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/; cross-repo audit ref --> (§3.2 line 1439–1445, §3.6 — preview is S5, per BD-3)
  - `main.list_sessions` identity-field extraction (§3.2 line 2055–2065)
  - `factory_bridge.map_config_to_factory_params` (§3.3 line 33–129)
  - `factory_bridge._build_content_from_config` (§3.3 line 142–190)
  - `factory_bridge.trigger_factory` config-fetch + translation (§3.3 line 209 + 210–211 + 250/253 — previously refactor-to-S2)
  - `factory_bridge_v2.prepare_demo_dict` (§3.4 line 35–63)
  - `factory_bridge_v2.trigger_factory_v2` config-fetch + translation (§3.4 line 82 + 97/109–115 + 118 + 140–143 — previously refactor-to-S2)
  - `factory_v2/validate_v2.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/factory_v2/; cross-repo audit ref --> (entire file, §3.5)
  - `sample-config.json` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/; cross-repo audit ref --> (§3.8)
  - `config_mgmt_client.patch_config` (§3.7 line 94–108 — previously refactor-capability-gap, per BD-4)
- **Refactor (keep-in-S1-but-rewrite) (5):**
  - `main.create_new_session_ui` agent-init send (§3.2 line 1219 — send identity fields as agent-init metadata only, no config)
  - `main.create_new_session` agent-init send (§3.2 line 1284 — same)
  - `main.session_page` brand-in-title (§3.2 line 1349 — fetch from S2 on render)
  - `main.chat` lazy-create title derivation (§3.2 line 1395–1397 — fetch from S2; drop `insuranceLine`)
  - `main.session_status` response shape (§3.2 line 1461–1472 — drop `logos` per BD-2; drop `configVersion` since it's not on the session doc; response is lifecycle-only)
  - `main.session_history` brand/config read (§3.2 line 1987–2001 — fetch from S2 for the summary; version history via S2's `listConfigVersions`)
  - `factory_bridge.trigger_factory` / `factory_bridge_v2.trigger_factory_v2` control-flow shell (§3.3 line 202, §3.4 line 75 — each `trigger_factory*` function reduces to: read session, `POST /build {sessionId}` to S3, write `factoryRunId` back)
- **Keep-as-is (3):**
  - `session.py::_UPDATABLE_FIELDS` (§3.1 line 133 — allowlist already clean; gate keeps it clean)
  - `config_mgmt_client.fetch_schema` / `fetch_config` (§3.7 line 71–79, 82–91 — unchanged)

## 4. S1 → S2 call shapes

All calls go through `config_mgmt_client.py`. Every call is Bearer-token authenticated via `CONFIG_MGMT_TOKEN` (shared secret, already configured — see session-state ADR §8 non-goals). Error mapping already exists in the client (`ValidationError`, `NotFoundError`, `UnauthorizedError`, `NetworkError`).

### 4.1 Fetch config for render/history

- **S2 endpoint:** `GET /v1/config/{session_id}` — operationId `getConfig`.
- **Query:** `version` (int, optional). Omitted = latest.
- **Request body:** none.
- **Response body:** `ConfigResponse` = `{ sessionId, config: DemoConfig, version, updatedAt }`.
- **Call sites in S1:** `main.session_page` (title derivation), `main.chat` (lazy-create title), `main.session_status` (if any identity field still surfaces — see §5.5), `main.session_history` (brand for summary). **Not** called on the factory path (OQ-BD-6: S3 fetches its own config). **Not** called for preview (OQ-BD-3: preview is S5).
- **Error handling:** on `NotFoundError` (S2 404), render the cold-session fallback (`brand = "New Session"`). Cold state is expected at session creation because S1 does not POST the first version — the first version appears when the agent's first `set_config` lands.

### 4.2 Create initial config at session creation — REMOVED

Per OQ-BD-5 resolution (c), S1 does **not** POST to S2 at session creation. The first config version is created by the managed agent via its first `set_config` MCP call. `configVersion` for the session lives on S2 from that point on. Prior to that call, there is no config for the session. S1 session creation is a single Firestore write; no outbound HTTP to S2.

### 4.3 Fetch schema for setup / history

- **S2 endpoint:** `GET /v1/schema` — operationId `getSchema`.
- **Call sites in S1:** none in the runtime today. Client method `fetch_schema()` stays available for future server-side schema-aware rendering; preview rendering specifically is S5.

### 4.4 List config versions for history view

- **S2 endpoint:** `GET /v1/config/{session_id}/versions` — operationId `listConfigVersions`.
- **Call sites in S1:** `main.session_history` (optional — version audit trail). Current code does not expose version history; session-state ADR §5 row 11 flagged history alignment as an SE.F follow-up.

## 5. Call-site transition detail

### 5.1 Session creation

Current (pseudo):
```
POST /session/new (S1)
  └── create_session(..., initial_context=SAMPLE_CONFIG + body fields)
      └── Firestore write: {sessionId, config: {...}, configVersion: 1, ...}
```

Target (post-BD, per OQ-BD-5 resolution (c)):
```
POST /session/new (S1)
  └── session_store.create_session(slack*)
      └── Firestore write: {sessionId, status: "configuring", createdAt, updatedAt, ...}
         (no `config`, no `configVersion`, no `brand`/`market`/`languages`/`shortcode` persisted)
  └── managed_agent.boot(sessionId, brand, market, languages, shortcode, ...)    ← agent-init metadata
         (identity fields are passed to the agent so it boots with them; not persisted on S1)
  └── return {sessionId, studioUrl}
```

S1 does **not** POST to S2 at creation. The first `POST /v1/config` on S2 happens later, when the managed agent runs its first `set_config` MCP call — which goes directly to S2 via the MCP server, bypassing S1. From S1's perspective, a new session has no config until the agent chooses to write one.

Identity fields (`brand`, `market`, `languages`, `shortcode`) are agent-input metadata — consumed by the managed agent to seed its reasoning context — and are not written to the S1 session doc. The exact agent-init message shape is Kayn's to refine in the SE.F.1 follow-up.

### 5.2 Chat / status / history / page render

Current: `session.get("config", ...)`.
Target: `config_mgmt_client.fetch_config(session_id)` — latest version.

Per-endpoint latency: one extra GET to S2 per render. For hot paths (status polling), consider a short-TTL in-process cache keyed by `sessionId` — an in-process dict with 30-second TTL is fine given single-instance Cloud Run.

### 5.3 Factory build — S1 becomes a thin pass-through

Current: `config = session.get("config", {})` followed by `map_config_to_factory_params(config)` and `_build_content_from_config(config, params)`.

Target (per OQ-BD-6 resolution, authoritative against `tools/demo-factory/api/factory.yaml:192` <!-- orianna: ok — company-os reference spec --> `required: [sessionId]`):

```
POST /session/{id}/build (S1)
  └── session_store.get_session(session_id)    # lifecycle-only; no config read
  └── session_store.transition_status(..., to="building")
  └── factory_client.start_build(session_id)   # POST /build {sessionId} to S3
         (no configVersion, no translated payload, no content dict)
  └── session_store.update_session(factoryRunId=...)
  └── return accepted
```

- **S3 spec cite:** `tools/demo-factory/api/factory.yaml` <!-- orianna: ok — company-os reference spec --> lines 186–203 define the `/build` POST body as `required: [sessionId]` with an optional `configVersion`. Per Duong's OQ-BD-6 resolution ("Factory always reads the latest version"), S1 supplies `{sessionId}` only; S3 fetches the latest config from S2 itself.
- **All translation deletes:** `map_config_to_factory_params`, `_build_content_from_config`, `prepare_demo_dict`, `validate_v2.py`, and every factory-path config read in `factory_bridge.py` / `factory_bridge_v2.py` delete from S1.
- **Build reproducibility** is no longer an S1 concern. If S3 needs version pinning for reproducibility it handles it via its own `configVersion` parameter against S2.

### 5.4 `cancel-build`, `complete`, `close`

None of these read config. All three stay as-is from session-state-ADR §5 perspective. No boundary-impact.

### 5.5 `GET /sessions` and `GET /session/{id}/status`

Per OQ-BD-1 resolution (strict), the S1 session doc does **not** hold `brand`, `market`, `languages`, or `shortcode`. Resolution:

- **A. Accept N+1 — ACCEPTED.** Any consumer of `/sessions` that needs identity fields fans out to S2 per session. Default page size = 20 → 20 S2 calls on top of the S1 list. N+1 is accepted for now. S2 batch-get (`GET /v1/configs?sessionIds=...`) remains a deferred ask — see §6.1.
- **B. Denormalise onto S1 — REJECTED.** Violates Rule 2 and BD-1.
- **C. Drop identity fields from S1's response shape — ADOPTED.** `GET /sessions` returns lifecycle-only `SessionSummary` rows: `{sessionId, status, phase, createdAt, updatedAt, managedSessionId?, factoryRunId?, projectId?}`.

**Consequence for `GET /session/{id}/status`:** response shape shrinks — no `logos` (per OQ-BD-2), no `configVersion` (not on session doc), no `brand`/`market`. Status is strictly lifecycle: `{status, phase, createdAt, updatedAt, managedSessionId?, factoryRunId?, projectId?, outputUrls?, qcResult?}`. UI code that wants identity context issues a parallel `GET /v1/config/{sessionId}` to S2.

## 6. S2 capability gaps — blockers

### 6.1 No list endpoint on S2

S2 exposes `GET /v1/config/{session_id}` (one session) and `GET /v1/config/{session_id}/versions` (one session's history), but **no `GET /v1/configs?sessionIds=...`** or equivalent batch endpoint. Without it, S1's `GET /sessions` must either N+1 (option A above) or denormalise (option B). Recommendation for S2 team: add `GET /v1/configs?sessionIds=id1,id2,...` or `POST /v1/configs:batch-get`. Not blocking option B.

### 6.2 No PATCH on S2 — RESOLVED

Per OQ-BD-4 resolution, `config_mgmt_client.patch_config` deletes from S1 outright. S2's contract is full-snapshot via `POST /v1/config` with immutable versioning; there is no PATCH endpoint and none is being requested.

### 6.3 No S2 → S1 change-notification channel — NOT APPLICABLE

Under BD-1 strict, S1 does not denormalise any config-shaped fields, so there is nothing on S1 to keep in sync. S2 change-notification is unnecessary from S1's side.

## 7. Sequencing vs. the session-state-encapsulation ADR

| This ADR (BD) | Session-state ADR (SE) | Ordering |
|---|---|---|
| BD.decide (this ADR) | SE.0, SE.A (audit + additive module) | Parallel — SE.A is purely additive storage plumbing; this ADR decides what data flows through it. |
| BD.implement: delete config writes in `session.py::create_session` | SE.A.4 (implement `session_store.create_session`) | **BD implementation must land INSIDE SE.A.4.** |
| BD.implement: delete `SAMPLE_CONFIG` + UI/internal create-session config plumbing in `main.py` | SE.B.2 (migrate `main.py` call sites) | **BD must land BEFORE SE.B.2.** |
| BD.implement: delete `map_config_to_factory_params`, `_build_content_from_config`, `prepare_demo_dict`, `validate_v2.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/factory_v2/ --> | SE.B.4 (migrate `factory_bridge*.py` <!-- orianna: ok — company-os file glob under missmp/company-os/tools/demo-studio-v3/ -->) | **BD must land BEFORE SE.B.4.** |
| BD.implement: add `config_mgmt_client` call sites for `preview` / `session_status` / `session_history` | SE.B.2 (same file) | **Parallelisable with SE.B.2.** |
| BD.implement: extend SE.E grep gate with config-boundary patterns | SE.E.2 (implement grep-gate CI) | **BD must land INSIDE SE.E.2.** |
| BD.implement: delete `sample-config.json` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ --> | SE.* (unrelated) | Any time. |
| BD.implement: initial config POST to S2 at session creation | SE.F.1 (`/session/new` spec alignment) | **Parallelisable.** |
| BD.implement: identity-field denormalisation (brand/market/languages/shortcode) | SE.A.4 / SE.A.6 (`session_store` fields) | **BD must land INSIDE SE.A.4.** |

**Verdict (per OQ-BD-7 resolution):** BD lands before SE.B.2 and SE.B.4. SE.A is additive and may proceed in parallel.
- **SE.0, SE.A.1–A.3:** independent of this ADR, can land first.
- **SE.A.4 onward:** must absorb BD changes. The SE dataclass no longer carries `brand/market/languages/shortcode`; amendment file spells out the new shape.
- **SE.B.2, SE.B.4:** must land with BD changes, not without.
- **SE.C (enum migration):** independent — this ADR does not touch the status enum.
- **SE.D (token TTL):** independent — tokens are not config.
- **SE.E.2:** must absorb BD grep-gate patterns.

## 8. Migration / rollback posture

### 8.1 In-flight sessions with embedded config

At migration time, the `demo-studio-sessions` collection has live rows with `config: {...}` and `configVersion: N` embedded. Options:

- **A. Backfill — copy each session's `config` to S2 as version 1.** A one-shot script iterates `demo-studio-sessions`, for each row calls `POST /v1/config` with `author: "backfill"`, captures the returned `version`, writes that version back to the S1 doc, then deletes the embedded `config` field. Risk: the embedded configs may fail S2 validation (legacy fields like `insuranceLine`, or missing required fields like `ipadDemo`). Mitigation: run with `force=true` and record each backfilled session's validation errors for audit.
- **B. Orphan — do not backfill; treat embedded `config` as tombstoned.** All currently-configuring sessions complete on the old path (pre-migration code still deployed as canary) or are cancelled. New sessions use the new path. Risk: any user with a session open at cutover has to restart. Given the low session volume today, this is the simpler option.
- **C. Lazy backfill — on-demand.** Deploy new code; on any request that reads config for a session that has embedded `config` and no S2 version, synthesise an S2 version via `POST /v1/config` then proceed. Risk: complicates the read path indefinitely.

**Recommendation:** B (orphan). Run a pre-deploy query `SELECT count(*) FROM demo-studio-sessions WHERE status IN ('configuring', 'building')` — if the count is manageable (likely single digits given current traffic), hand-walk those users. Document in the deploy runbook.

### 8.2 Per-endpoint flip strategy

Phase each endpoint independently:
- `POST /session/new` — flip atomically. New sessions post-deploy use the new path. No outbound S2 call at creation.
- `POST /session` (internal) — flip atomically. Same reasoning.
- `GET /session/{id}/preview` — **deletes** as an S1 route (OQ-BD-3). Traffic redirect/410 handling is an S5 concern.
- `GET /session/{id}/status`, `/history`, `/session/{id}` (page) — flip atomically per deploy. Read paths tolerate S2-fetch or fall back to "New Session" on S2 404 / 5xx.
- `POST /session/{id}/build` — flip atomically to the thin `POST /build {sessionId}` pass-through. S3 is already contract-aligned on `{sessionId}` per `tools/demo-factory/api/factory.yaml:192` <!-- orianna: ok — company-os reference spec --> (§5.3), so no S3-side coordination is strictly required for payload compatibility — only confirmation that S3's self-fetch path is live. Sona to confirm with S3 team before flip.
- `POST /session/{id}/approve` — scheduled for delete per SE.B.8; BD does not change that posture.

### 8.3 Rollback

Per-phase revert is straight git revert, same as session-state ADR §7. Because BD-1 strict means identity fields never landed on the session doc post-migration, rollback doesn't conflict with existing writes — there's nothing to "un-populate".

## 9. Consequences

- **S1 shrinks — significantly more than the previous draft.** ~150+ LOC from `SAMPLE_CONFIG` + `map_config_to_factory_params` + `_build_content_from_config` + `prepare_demo_dict` + `validate_v2.py` + `sample-config.json`, plus `preview.py` + the `/preview` route, plus `patch_config`. Estimated total deletion: >250 LOC.
- **Read-path latency increases by one S2 GET per render** (only where identity fields are needed: `session_page` title, `chat` lazy-create title, `session_history` summary). Mitigated by in-process short-TTL cache on hot paths.
- **S2 becomes a hard runtime dependency for S1 UI renders that include identity fields.** Today, S1 renders even if S2 is down (reads cached config out of session doc). Post-migration, those renders degrade to "New Session" fallback on S2 404 / 5xx. Acceptable per Duong's posture; S2 is infrastructure, not a soft dependency.
- **Factory builds are determinism-agnostic at the S1 boundary.** S1 does not capture `configVersion` at build start; S3's self-fetch reads latest. If build reproducibility is required, it's an S3 concern.
- **The MCP server is unchanged.** It already writes to S2 directly; S1 was never in that path.
- **Tests simplify.** `test_config_mgmt_client.py` <!-- orianna: ok — company-os test file under missmp/company-os/tools/demo-studio-v3/tests/ --> tests become live-integration. `test_no_local_validation.py` <!-- orianna: ok — company-os test file under missmp/company-os/tools/demo-studio-v3/tests/ --> finally passes without further action. ~15 call-sites stop mocking `session.get("config", ...)`.
- **SE ADR `Session` dataclass shrinks.** `brand`, `market`, `languages`, `shortcode` drop. `configVersion` drops. See sibling amendment file.
- **`/preview` route goes away on S1.** S5 picks it up. Out of scope for this ADR; flagged for whoever owns S5.
- **No S2 writes from S1 at creation.** S1 becomes a pure session-lifecycle service + agent host. Every config mutation is agent-initiated via MCP → S2.

## 10. Non-goals (explicit)

- **NOT** changing S2. Every S2-side gap is flagged for the S2 team, not designed around.
- **NOT** redesigning the factory translation (`map_config_to_factory_params`). This ADR decides it leaves S1; where it lands on the S3 side is S3's ADR to write.
- **NOT** implementing anything. Per Azir boundaries — architecture-only, no code changes. Kayn/Aphelios decompose into tasks; Jayce/Viktor implement.
- **NOT** modifying the session-state ADR. Extensions only, via the amendments documented in §7.
- **NOT** redefining `configVersion` semantics. It remains a monotonic int pointer maintained by S2 and mirrored onto S1 post-write.

## 11. Resolutions (Duong, 2026-04-20 s3)

All seven open questions resolved. Revisions incorporated above; this section records the authoritative decisions and the sections amended per resolution.

- **OQ-BD-1 — RESOLVED: Strict.** No denormalisation. S1 session doc holds lifecycle fields only (`sessionId`, `createdAt`, `updatedAt`, `status`, `phase`, agent pointer, `factoryRunId`). `brand`, `market`, `languages`, `shortcode` are NOT session-persisted — they are config/agent-input. Any consumer that needs identity fields (`/sessions` list, titles in `main.session_page` / `main.chat`, `main.session_history` summary) fetches from S2. N+1 is accepted for now; S2 batch-get remains a deferred ask (§6.1). Amended sections: §2 Rule 1, §3.14, §5.5, §6.1.
- **OQ-BD-2 — RESOLVED: Drop.** `GET /session/{id}/status` no longer returns `logos`. Response shrinks to lifecycle-only (`sessionId`, `status`, `phase`, `createdAt`, `updatedAt`, `factoryRunId?`). Aligns with session-state ADR SE.F.3 follow-up. Amended: §3.2 row 1461–1472, §3.14 Refactor entry for `session_status`.
- **OQ-BD-3 — RESOLVED: Out of scope for S1.** Preview is S5 (iframe; see `reference/5-preview.yaml` <!-- orianna: ok — company-os reference spec -->). S1 does not track `configVersion` for UI pinning. `configVersion` is not required on the S1 session doc and is removed. Amended: §3.1 `configVersion` write now in Delete list; §5.3 build trigger does not pin version.
- **OQ-BD-4 — RESOLVED: Delete.** `config_mgmt_client.patch_config` removed. S2's contract is canonical: `POST /v1/config` full-snapshot with immutable monotonic versioning. Amended: §3.7 row 94–108 → Delete; §6.2.
- **OQ-BD-5 — RESOLVED: Option (c).** S1 does NOT `POST /v1/config` at session creation. `configVersion` is absent on the session doc; the first config version is produced by the agent's first `set_config` MCP tool call landing on S2. Amended: §4.2 ("REMOVED"), §5.1, §5.5.
- **OQ-BD-6 — RESOLVED: Confirmed from spec.** `reference/3-factory.yaml` <!-- orianna: ok — company-os reference spec --> `/build` requestBody schema is `{required: [sessionId]}`. Description: "Factory always reads the latest version; pinning to a historical version is out of scope." S1 passes only `sessionId` to S3. S3 self-fetches config from S2. All S1 translation code deletes. `trigger_factory*` reduces to: read session → `POST /build {sessionId}` → persist `factoryRunId`. Amended: §3.3, §3.4, §3.5, §3.14, §5.3.
- **OQ-BD-7 — RESOLVED: Confirmed.** BD lands before SE.B.2 and SE.B.4. SE.A is additive and proceeds in parallel. SE.B call-site migrations must see the post-BD shape. Amended: §7 sequencing table stands.

**Net scope redefinition (Duong, verbatim):** "we only care about creation of the config and manage sessions of the managed agent." Interpretation locked in: S1 = (a) host the Anthropic managed agent, (b) track the agent's session lifecycle, (c) forward requests to/from the agent. Nothing else. The §3.14 delete list (17 rows) executes this scope.

**See also:** `company-os/plans/2026-04-20-session-state-encapsulation-bd-amendment.md` <!-- orianna: ok — cross-repo amendment; lives in missmp/company-os --> — companion amendment that names the session-state ADR sections and tasks that change as a consequence of these resolutions.

## 12. Handoff

- **Kayn / Aphelios:** decompose §7 amendments into new `SE.A.4b`, `SE.A.13`, `SE.B.2b`, `SE.B.4b`, `SE.B.9`, `SE.E.2b` tasks (or renumber as appropriate). Do not promote to tasks until OQ-BD-1, -4, -5, -6, -7 are resolved.
- **Orianna:** fact-check the 15-path enumeration in §3 against `feat/demo-studio-v3@d327581`. Line numbers drift; rebaseline on task-file promotion.
- **Sona:** coordinate OQ-BD-6 with the S3 team, and surface §6.1 (batch GET), §6.2 (PATCH fate), §6.3 (change notifications) to the S2 team.
- **Camille:** owns the SE.E grep gate; will absorb the two extra patterns from §2 Rule 4 when SE.E.2 is decomposed.
- **Jayce / Viktor:** no action yet — plan only. Once tasks land, the deletion work (per §3) is a week or two of mostly-mechanical surgery across `main.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ -->, `factory_bridge*.py` <!-- orianna: ok — company-os file glob under missmp/company-os/tools/demo-studio-v3/ -->, `session.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ -->, `factory_v2/` <!-- orianna: ok — company-os directory under missmp/company-os/tools/demo-studio-v3/ -->.

## Test plan

Enforcement is structural and gate-based rather than runtime; per ADR §2 Rule 4 and the SE.E grep gate:

- **I1 — Config-boundary gate:** the extended SE.E.2 grep gate asserts no file under `company-os/tools/demo-studio-v3/` <!-- orianna: ok — grep-gate scope string referring to missmp/company-os; not a local filesystem path --> (other than tests and migration scripts) reads or writes `session["config"]` or holds the literal `insuranceLine`; CI fails on any violation.
- **I2 — Identity-field exclusion:** SE.A.3/A.4 tests (in the session-state ADR) assert the Firestore write payload for `create_session` contains no `brand`, `market`, `languages`, `shortcode`, or `configVersion` keys; `update_session` rejects those names as unknown fields.
- **I3 — Factory pass-through shape:** SE.B.4 regression tests assert `trigger_factory*` functions no longer call `map_config_to_factory_params`, `_build_content_from_config`, or `prepare_demo_dict`, and that the outbound S3 call carries `{sessionId}` only.
- **I4 — Deleted symbols absent:** SE.B.4 acceptance criteria assert `validate_v2.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/factory_v2/; deletion acceptance criterion --> and `sample-config.json` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/; deletion acceptance criterion --> no longer exist in the repo after the deletion PR merges.
