---
title: "Firestore Config-Mgmt Leak Investigation"
date: 2026-04-22
concern: work
author: ekko
---

# Firestore Config-Mgmt Leak Investigation

## 1. demo-config-mgmt Schema Summary

**DB:** `projects/mmpt-233505/databases/demo-config-mgmt`
**Region:** europe-west3 (Firestore Native, created 2026-04-17)

### Collections

**`configs`** — 3 documents (test/smoke data only, not live production writes)

Document shape:
```
{
  session_id: str          # used as document ID too (e.g. "smoke-test", "tungTestCSR_English")
  version: int             # integer revision counter (currently 1 or 4)
  config: dict             # full config payload — all brand/market/config fields
  created_at: timestamp
  updated_at: timestamp
}
```

Sample `config` top-level keys: `brand`, `market`, `languages`, `shortcode`, `card`, `params`,
`logos`, `tokenUi`, `colors`, `ipadDemo`, `journey`, `googleWallet`, `insuranceLine`, `persona`, `ios`

Document IDs are human slugs (e.g. `smoke-test`, `tungTestCorporateSpecialRisks`) — NOT UUID hex.
There is no explicit "latest pointer" collection and no separate versions subcollection.

**`reports`** — 1 document (QC/verification run output)

Document shape:
```
{
  sessionId: str
  projectId: str
  status: str           # "pass" / "fail"
  runAt: timestamp
  summary: dict         # {total, passed, failed, skipped}
  checks: list          # [{name, status, actual, expected, category}]
  diagnosis: list       # [{check, type, suggestion}]
  duration_ms: float
}
```

### Key finding: demo-config-mgmt has NO live Firestore writes from the running service

The `demo-config-mgmt` Cloud Run service (`tools/demo-config-mgmt/main.py`) currently stores
all config data **in-process** in a Python `dict` (`_session_configs`). It does NOT write to
the `demo-config-mgmt` Firestore DB at runtime. The 3 docs in the `configs` collection are
manual/smoke-test artefacts. The `reports` collection was written by an external QC tool.

There is no `config_id` concept in the `demo-config-mgmt` DB — document IDs are currently
session-ID strings (the same string the caller uses as the "session id"). A proper `config_id`
FK schema does not yet exist.

---

## 2. Current Session-Store Schema + Leaked Fields

**DB:** `projects/mmpt-233505/databases/demo-studio-staging`
**Collections:** `demo-studio-sessions`, `demo-studio-used-tokens`

### Intended session-store schema (BD-1 strict, per `session_store.py`)

```
sessionId         str       — hex UUID
status            str       — lifecycle FSM state
phase             str|None
managedSessionId  str|None
factoryRunId      str|None
projectId         str|None
outputUrls        dict|None
qcResult          dict|None
slackUserId       str|None
slackChannel      str|None
slackThreadTs     str|None
archivedAt        timestamp|None
createdAt         timestamp
updatedAt         timestamp
```

### Actual fields in all 96 production session docs

Sampling confirms **every single one of the 96 docs** contains these additional fields:

| Field | Type | Leak? | Notes |
|---|---|---|---|
| `config` | dict | **YES** | Full config payload: brand, market, languages, shortcode, card, logos, tokenUi, colors, etc. |
| `configVersion` | int | **YES** | Always `1` (hardcoded at create time) |
| `factoryVersion` | int | **YES** | Always `2` (hardcoded at create time) |

No doc contains a `configId` FK field.

### Sample `config` dict keys (from a real session doc)

```
demoSteps, shortcode, params, brand, persona, ios, hubspotDealId,
languages, logos, market, card, tokenUi, journey, colors, googleWallet, insuranceLine
```

This is the full config payload — identical to the config stored in `demo-config-mgmt`.

---

## 3. Call Sites That Write the Leaked Fields

### Primary writer: `session.py::create_session` (lines 38-52)

This is the **old** session module (pre-BD-1 refactor). It is still the module imported and
called by `main.py`. The `session_store.py` module (the BD-1-compliant replacement) exists
but is only used for the `managed-sessions` join query path (`batch_get_by_managed_ids`).

```python
# session.py, lines 38-52  — the leak source
doc = {
    "sessionId": session_id,
    "status": "configuring",
    "phase": "configure",
    "config": initial_context or {},     # <<< LEAK — full config blob
    "configVersion": 1,                  # <<< LEAK
    "factoryVersion": 2,                 # <<< LEAK
    ...
}
db.collection(SESSIONS).document(session_id).set(doc)
```

Called from two routes in `main.py` (line 46 import: `from session import create_session, ...`):

- **Line 1676** — `POST /session/new` (UI path): `create_session(slack_user_id="ui", slack_channel="ui", slack_thread_ts="ui")` — no `initial_context` arg, so `config={}` (empty dict, still written).
- **Line 1732** — `POST /session` (Slack relay path): `create_session(..., initial_context=body.initialContext)` — caller may pass a full config payload, writing it directly into the session doc.

### Secondary reader (uses leaked field): `main.py::trigger_build` (line 2172)

```python
version = session.get("factoryVersion", 1)
```

This reads `factoryVersion` from the session dict to route factory bridge calls. If the field
is removed from session docs, this line will silently fall back to `1` (which is the wrong
version — factory v2 should be used). This fallback must be updated.

### Secondary reader: `session.py::list_recent_sessions` (line 118)

```python
config = d.get("config") or {}
brand = config.get("brand", "")
```

The dashboard listing reads `brand`/`market`/`insuranceLine` directly from the session `config`
blob. After the fix, this must be replaced with an S2 fetch via `config_mgmt_client.fetch_config`.

### The `config_id` FK does NOT exist anywhere

There is no `configId` field in any session doc or any write path. It must be added as a new
field.

---

## 4. Proposed New Session-Store Schema

After the fix, session docs should contain ONLY:

```
sessionId         str
status            str
phase             str|None
managedSessionId  str|None
factoryRunId      str|None
projectId         str|None
outputUrls        dict|None
qcResult          dict|None
slackUserId       str|None
slackChannel      str|None
slackThreadTs     str|None
archivedAt        timestamp|None
createdAt         timestamp
updatedAt         timestamp
cancelReason      str|None      (already present on some docs)
verificationStatus str|None     (Phase D field)
verificationReport dict|None    (Phase D field)
lastBuildAt       str|None      (Phase D field)
config_id         str           <<< NEW — FK to demo-config-mgmt doc ID (session_id string)
```

`config`, `configVersion`, and `factoryVersion` are removed entirely.

The `config_id` value: since `demo-config-mgmt` currently keys its docs by `session_id`,
the FK value is simply the session ID itself (at least until demo-config-mgmt introduces
independent UUID-keyed config docs, which would need a separate migration).

---

## 5. Wipe-and-Restart Plan Outline

### DB-side

1. **Wipe `demo-studio-staging` session collection.** All 96 docs are dev/staging sessions
   with no production dependency. The `demo-studio-used-tokens` collection can be left or
   also wiped (it's a one-time-token replay cache — wipe is safe, worst case is a token
   replay window for already-issued links).
   
   Command shape (requires Firestore admin SDK or gcloud CLI with delete support):
   ```
   # Via Python admin SDK:
   for doc in db.collection("demo-studio-sessions").stream():
       doc.reference.delete()
   ```
   
   Note: `gcloud firestore documents delete` is collection-level only via the REST API or
   admin SDK; the CLI does not expose a bulk-delete command. A short Python script is the
   cleanest approach.

2. **No changes needed to `demo-config-mgmt` DB.** The 3 manual test docs can stay.
   Once the service is wired to write to Firestore (rather than in-memory), new docs will
   appear with the correct schema.

### Code-side

1. **`session.py::create_session`** — strip `config`, `configVersion`, `factoryVersion` from
   the `doc` dict. Add `configId: session_id` (until config IDs are independent UUIDs).

2. **`main.py` import** — consider migrating `main.py` to import `create_session` from
   `session_store.py` instead of `session.py`. `session_store.py` already enforces BD-1;
   `session.py` is the pre-refactor file. Short-term: fix `session.py` in place.

3. **`main.py::trigger_build` (line 2172)** — remove `session.get("factoryVersion", 1)`.
   Hard-code factory v2 (the `factoryVersion` field was always `2` in all 96 docs), or
   derive version from config/plan rather than session state.

4. **`session.py::list_recent_sessions`** — replace `config.get("brand")` / `config.get("market")`
   reads with S2 fetch via `config_mgmt_client.fetch_config(session_id)`. This mirrors the
   pattern already in `main.py::dashboard_sessions` (lines 3047-3097).

5. **`session_store.py::_UPDATE_ALLOWLIST`** — add `config_id` to the allowlist so it can
   be updated later if config docs get independent IDs.

### Tests to update

- `tests/conftest.py` (line 160): fixture creates session doc with `configVersion: 1` and
  `factoryVersion: 2` — strip these.
- Any test that calls `session.create_session` and asserts on `config` / `configVersion` /
  `factoryVersion` fields in the returned dict.
- `tests/test_session_store_no_config_write.py` — likely already tests BD-1 compliance;
  verify it covers `config_id` presence.
- `session.py::list_recent_sessions` tests — will need mocked S2 calls after the config-
  read is moved to fetch_config.

---

## 6. Open Questions for Duong

1. **`config_id` identity shape.** Should `config_id` remain the same string as `session_id`
   (current demo-config-mgmt doc key pattern), or should demo-config-mgmt be refactored to
   use independent UUID doc IDs so a session can reference a _different_ config version?
   This changes the migration complexity significantly.

2. **demo-config-mgmt Firestore write wiring.** The S2 service is entirely in-memory today —
   configs are lost on pod restart. Is the plan to wire S2 to persist to the `demo-config-mgmt`
   Firestore DB as part of this fix, or is that a separate track? The Firestore DB already
   exists and has a sensible structure; the service just isn't writing to it.

3. **`factoryVersion` removal blast radius.** The build trigger reads `factoryVersion` from
   the session doc. Is it safe to hard-code factory v2 everywhere, or is there any session
   that legitimately needs factory v1?

4. **`list_recent_sessions` degradation mode.** After the fix, fetching brand/market for the
   dashboard listing requires an S2 call per row. Should this use the same parallel-fetch
   pattern already in `main.py::dashboard_sessions`, or is a cached/denormalized approach
   preferred to avoid latency?

5. **Token replay window on wipe.** Wiping `demo-studio-used-tokens` alongside sessions is
   cleanest but opens a token-replay window for any one-time URLs already issued (e.g.
   `/auth/session/<id>?token=<tok>`). Is this acceptable for staging, or should tokens be
   preserved?

6. **Session doc `archivedAt` field.** Several existing docs use status `"archived"` (a
   legacy status). The `migrate_session_status.py` script maps `archived` to `completed` or
   `cancelled`. Should the wipe make this migration moot, or should the migration script be
   run before wipe as a record?
