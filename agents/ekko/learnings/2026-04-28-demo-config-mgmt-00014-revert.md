# 2026-04-28 — demo-config-mgmt 00014-2bn revert findings

## Task
Flip demo-config-mgmt traffic to revision 00014-2bn (tuan.pham@missmp.eu's last revision),
run binding smoke test, inspect /v1/schema.

## Key findings

### API shape differs between revisions
- 00015-c7b accepted top-level `session_id` + `brand` fields (snake_case)
- 00014-2bn requires camelCase `sessionId` + nested `config` object (FastAPI Pydantic model)
- 00014-2bn /v1/schema validates against the full canonical schema (all required fields)
- Use `?force=true` for smoke tests with partial configs that would fail schema validation

### 00014-2bn schema state
- /v1/schema: 200 OK, 19415 bytes
- Canonical 524-line schema is PRESENT (card, params, ipadDemo, journey, tokenUi all present)
- No `TODO: implement` comment, no MOCK_SCHEMA_YAML
- This is BETTER than 00015-c7b which had the mock stub (~1031 bytes)

### Binding result
PASS — POST `brand: Aviva-tuan-revert-test` with `?force=true` → version 1 created.
GET immediately returned identical config with `brand: Aviva-tuan-revert-test`.

## Token location
`tools/demo-config-mgmt/.env` has `CONFIG_MGMT_TOKEN=<value>` in plaintext.
This is the same secret as `DS_CONFIG_MGMT_TOKEN` in Cloud Run.

## Current state after this session
- Live revision: demo-config-mgmt-00014-2bn (100% traffic)
- Rollback option: demo-config-mgmt-00015-c7b (had mock schema stub)
