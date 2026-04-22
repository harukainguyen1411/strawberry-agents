# 2026-04-22 — Firestore Config-Mgmt Leak Investigation

## What I found

**The leak is entirely in `session.py::create_session`, not `session_store.py`.**

`session_store.py` is the BD-1-compliant refactored module — it correctly excludes all
identity/config fields. But `main.py` still imports `create_session` from the OLD `session.py`
module (line 46: `from session import create_session, ...`). The `session_store.py` module is
only used for the `batch_get_by_managed_ids` managed-sessions path.

`session.py::create_session` hard-codes `config: initial_context or {}`, `configVersion: 1`,
`factoryVersion: 2` into every session doc written to demo-studio-staging Firestore.

**All 96 docs in demo-studio-staging carry the leaked fields.** Zero docs have a `configId` FK.

## demo-config-mgmt DB facts

- Two collections: `configs` (3 test docs) and `reports` (1 doc)
- Doc IDs in `configs` are human slugs = same string as session_id
- The S2 service (`tools/demo-config-mgmt/main.py`) is **in-memory only** — it does NOT
  write to the Firestore DB at runtime. The DB docs are old manual/smoke test artefacts.
- `config_id` concept does not exist anywhere yet

## Key code paths

- **Leak writer:** `tools/demo-studio-v3/session.py:38-52` — `create_session()`
- **Stale reader 1:** `main.py:2172` — `session.get("factoryVersion", 1)` for build routing
- **Stale reader 2:** `session.py:118` — `config.get("brand")` in `list_recent_sessions()`
- **Good pattern (already fixed):** `main.py:3047-3097` — dashboard uses `config_mgmt_client.fetch_config()` per row

## For the fix plan

- `session.py` is the pre-refactor file; the fix is to strip 3 fields from its `create_session` doc dict
- `factoryVersion` can be hard-coded to 2 (all 96 live docs have it as 2)
- `list_recent_sessions` needs S2 fetch to get brand/market after `config` field removal
- Wipe of demo-studio-staging is safe — staging only, no prod traffic
- `config_id` FK = session_id string (matches existing demo-config-mgmt doc key pattern)
