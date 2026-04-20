# Demo Studio 5-Service Architecture Decisions

Date: 2026-04-16

## Key decisions made during this session

1. **5 independent services**, not a monolith. Each has its own API, deployment, and team:
   - Service 1: Content Gen (us) — chat UI, Managed Agent, MCP proxy
   - Service 2: Config Mgmt — schema, validation, persistence, sessions
   - Service 3: Factory — config -> WS project
   - Service 4: Verification — deterministic QC
   - Service 5: Preview — config -> branded HTML

2. **Config Mgmt (Service 2) is the hub.** All other services fetch config from it via `GET /v1/config/{session_id}`. Factory, Verification, and Preview all depend on it. No service receives config as a request body — they all fetch it by session_id.

3. **Validation is implicit on write.** No separate validate endpoint. PATCH returns 200 if valid, 400 with field-level errors if not. The `validate_config` MCP tool was removed entirely.

4. **Factory build returns SSE**, not JSON + polling. Five event types: step_start, step_complete, step_error, build_complete, build_error.

5. **No approve step.** User clicks "Generate" = approval + build trigger in one action.

6. **Service 1 is stateless.** Sessions and config both in Service 2's Firestore. Conversation history in Managed Agent (Anthropic-hosted). Service 1 owns no database.

7. **MCP server has exactly 3 tools**: get_schema, get_config, set_config. All proxy to Config Mgmt API.

8. **Config Mgmt API versioned from the start** (`/v1/config/...`). Other services are not versioned.

9. **Schema source of truth**: `tools/demo-studio-schema/schema.yaml` (PR #37). get_schema returns raw YAML with comments.

10. **API docs via Stoplight**, not a custom portal. OpenAPI specs in the `api` repo, Stoplight auto-syncs.

## Gotchas

- The architecture changed 3 times during the session (monolith -> 3 services -> 5 services). Plans need to be fully rewritten, not incrementally patched, when the architecture changes fundamentally.
- PR #37 schema uses `ipadDemo` not `demoSteps`, `params` not `persona`, `wideLogo`/`squareLogo` not `wordmark`/`icon`. Always check PR #37 for canonical field names.
- `tokenUi` in PR #37 is `additionalProperties: i18nText` (dotted-path keys), not the old nested `consentPage`/`getPassPage` structure.
