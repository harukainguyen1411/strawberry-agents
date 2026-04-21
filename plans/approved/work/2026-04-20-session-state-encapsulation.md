---
status: approved
orianna_gate_version: 2
complexity: normal
concern: work
owner: Sona
created: 2026-04-20
tags:
  - demo-studio
  - service-1
  - firestore
  - refactor
  - work
tests_required: true
orianna_signature_approved: "sha256:dfcb31707bda795ed66093c660e3a39cb04843d040e14a68a426a020ae3a3da5:2026-04-21T06:48:29Z"
---

# ADR: Demo Studio v3 — Session State Encapsulation (Service 1)

<!-- orianna: ok — all bare module names throughout this plan (session.py, session_store.py, main.py, auth.py, factory_bridge.py, factory_bridge_v2.py, dashboard_service.py, phase.py, test_session_store_types.py, test_session_store_crud.py, test_firestore_boundary_gate.py, firestore-boundary-gate.sh) are company-os files under missmp/company-os/tools/demo-studio-v3/; this plan is an architectural spec for that repo -->

**Date:** 2026-04-20
**Author:** Azir (architecture)
**Scope:** Service 1 only. Service 2 (`demo-config-mgmt`) is **not** touched.
**Supersedes:** prior draft `2026-04-20-session-api-on-service-2.md` <!-- orianna: ok — superseded old draft in company-os; no longer exists --> (scope-reversed: this ADR keeps sessions on Service 1). <!-- orianna: ok -->

## 1. Context

Session state lives on Service 1 and stays there. Our team owns Service 1; Service 2 is config-only and is owned by a different team. The problem is not *where* the state lives — it is that Firestore access is scattered across half-a-dozen modules with no single boundary.

### 1.1 Concrete scattering (audit, 2026-04-20)

<!-- orianna: ok — all bare module names in this section (session.py, main.py, auth.py, factory_bridge.py, factory_bridge_v2.py, dashboard_service.py, session_store.py, phase.py) are company-os files under missmp/company-os/tools/demo-studio-v3/; this is an architecture audit listing call-site locations -->

- `session.py` <!-- orianna: ok --> — partial wrapper: `get_db`, `create_session`, `get_session`, `update_session_status`, `transition_session_status`, `list_recent_sessions`, `update_session_field`. Imports `google.cloud.firestore` at module scope.
- `main.py:36` <!-- orianna: ok --> — imports `get_db` and calls it directly at lines `80`, `247`, `2043`. Line `2046` re-imports `google.cloud.firestore` inline to build a `Query.DESCENDING` cursor for `GET /sessions`.
- `auth.py:24-27` <!-- orianna: ok --> — `_get_db()` reaches back into `session.get_db()` to run a Firestore transaction against `demo-studio-used-tokens` (one-time URL tokens).
- `factory_bridge.py:18` <!-- orianna: ok --> and `factory_bridge_v2.py:24` <!-- orianna: ok --> — import `update_session_status`, `update_session_field` from `session.py`. Fine today, but they are coupled to the session storage module's surface rather than a stable API.
- `dashboard_service.py` <!-- orianna: ok --> — reads its session list via `list_recent_sessions()` (transitive Firestore).

Tests reflect the sprawl: ~15 test files `patch("session.get_db", ...)`. Every one is a Firestore-shaped mock.

### 1.2 What this ADR is NOT

- **NOT** moving sessions to Service 2.
- **NOT** adding endpoints to Service 2.
- **NOT** changing the Config API.
- **NOT** removing Firestore from Service 1.

Firestore stays. Service 1 stays stateful. The only thing that changes is who is allowed to talk to Firestore.

### 1.3 Spec drift vs PR #40 `reference/1-content-gen.yaml` <!-- orianna: ok — company-os reference spec under missmp/company-os/reference/; not a local filesystem path --> <!-- orianna: ok -->

Noted here because aligning the HTTP layer is part of this ADR's scope (§6). Not blocking for the module extraction itself.

| Area | Current Service 1 code | PR #40 spec |
|---|---|---|
| `SessionStatus` values | `configuring / approved / building / complete / failed / archived` | `configuring / building / built / qc_passed / qc_failed / build_failed / completed / cancelled` |
| `POST /session/new` body | `{brand, insuranceLine, market, closeSessionId?}` (cookie-auth UI route) | `{brand, market, languages, shortcode, slackUserId?, slackChannel?, slackThreadTs?}` |
| Approve flow | `POST /session/{id}/approve` exists (line 1482) | No `approved` state; no approve endpoint |
| Internal session create | `POST /session` (X-Internal-Secret, line 1238) | Not in spec |
| Archive flow | `POST /session/{id}/close` + sets `status=archived` | No `archived` status; `cancelled` instead |
| `GET /sessions` pagination | Unbounded `.stream()` over entire collection | Spec: `limit + offset` (default 50, max 200); ADR prefers cursor (§6) |
| `SessionSummary` shape | `{sessionId, brand, line, market, status, phase, createdAt, duration_s, cost_usd, authUrl}` | `{sessionId, brand, market, shortcode, status, configVersion, createdAt, updatedAt}` |

Flag list for the API team lives in §6.3.

## 2. Decision

Introduce a **single in-process session store module** — `session_store.py` <!-- orianna: ok --> — that is the *only* place in Service 1 allowed to import `google.cloud.firestore`. Every other module calls its public Python API.

The Session "API" is in-process (module-level). Existing Service 1 HTTP routes (`/session/*`, `/sessions`) continue to be the external surface and get aligned to PR #40 `reference/1-content-gen.yaml` as a follow-up. No new HTTP endpoints, no new services, no new secrets. <!-- orianna: ok -->

### 2.1 The boundary rule

```
ALLOWED:     session_store.py  ────►  google.cloud.firestore
FORBIDDEN:   anything_else.py  ────►  google.cloud.firestore
```

Enforced by a grep gate in CI (Camille, §4.5). A single `# azir: boundary` comment on the import in `session_store.py` <!-- orianna: ok --> is the only whitelisted occurrence.

## 3. Module shape — `session_store.py` <!-- orianna: ok -->

Draft public API. Signatures are proposals; exact types land with the implementation PR.

```python
# session_store.py — single Firestore boundary for Service 1.
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Optional, Literal

SessionStatus = Literal[
    "configuring", "building", "built",
    "qc_passed", "qc_failed", "build_failed",
    "completed", "cancelled",
]

@dataclass(frozen=True)
class Session:
    session_id: str
    status: SessionStatus
    phase: str | None
    brand: str
    market: str
    languages: list[str]
    shortcode: str
    config_version: int | None
    managed_session_id: str | None
    factory_run_id: str | None
    project_id: str | None
    output_urls: dict[str, str] | None
    qc_result: dict[str, Any] | None
    slack_user_id: str | None
    slack_channel: str | None
    slack_thread_ts: str | None
    archived_at: datetime | None
    created_at: datetime
    updated_at: datetime

@dataclass(frozen=True)
class SessionEvent:
    seq: int
    type: str              # message | config_update | build_started | build_complete | qc_completed | ...
    at: datetime
    payload: dict[str, Any]

@dataclass(frozen=True)
class Page:
    items: list[Session]
    next_cursor: str | None

# --- Sessions ---------------------------------------------------------------
def create_session(
    *, brand: str, market: str, languages: list[str], shortcode: str,
    slack_user_id: str | None = None,
    slack_channel: str | None = None,
    slack_thread_ts: str | None = None,
) -> Session: ...

def get_session(session_id: str) -> Session | None: ...

def update_session(session_id: str, **fields: Any) -> Session:
    """Partial update. Allowlist enforced internally; raises on unknown fields."""

def transition_status(
    session_id: str, *, from_status: SessionStatus, to_status: SessionStatus,
) -> bool:
    """Atomic CAS. Returns True if the transition happened, False if another writer beat us."""

def list_sessions(
    *, cursor: str | None = None, limit: int = 20,
    status: SessionStatus | None = None,
) -> Page:
    """Cursor-based listing, reverse-chronological. Opaque cursor."""

# --- Events (subcollection) -------------------------------------------------
def append_event(session_id: str, event: SessionEvent) -> None: ...

def get_events(
    session_id: str, *, cursor: str | None = None, limit: int = 100,
) -> Page: ...  # Page[SessionEvent] in practice

# --- Auth tokens (in-process, NOT Firestore) --------------------------------
def try_consume_token(token_hash: str, *, ttl_seconds: int = 3600) -> bool:
    """One-time URL token consume. In-process TTL cache; see §4.1 Phase D."""
```

**Call-site expectations** after migration: <!-- orianna: ok — all bare module names below (main.py, auth.py, factory_bridge.py, factory_bridge_v2.py, dashboard_service.py, session_store.py) are company-os files under missmp/company-os/tools/demo-studio-v3/ -->

- `main.py` <!-- orianna: ok --> removes every `get_db()` call and every `from google.cloud import firestore` import.
- `auth.py` <!-- orianna: ok --> loses `_get_db()` entirely and calls `session_store.try_consume_token(...)`.
- `factory_bridge.py` <!-- orianna: ok --> / `factory_bridge_v2.py` <!-- orianna: ok --> switch from `update_session_status` / `update_session_field` to `session_store.update_session(...)` / `session_store.transition_status(...)`.
- `dashboard_service.py` <!-- orianna: ok --> calls `session_store.list_sessions(...)` instead of `list_recent_sessions()`.

## 4. Firestore layout

Under Service 1's existing Firestore project. No new databases. The `demo-studio-sessions` collection is reused in place.

<!-- orianna: ok — the paths below are Firestore collection paths, not filesystem paths -->
```
demo-studio-sessions/{sessionId}
demo-studio-sessions/{sessionId}/events/{seq}
```

That is the entire footprint. Removed: `demo-studio-used-tokens` (moves to in-process TTL cache per Q4 lock; §4.1 Phase D).

### 4.1 Event history — subcollection, not embedded

Locked per Q3: `sessions/{id}/events/{seq}` subcollection. No embedded `eventHistory` array. No soft 500 cap. Document key is a zero-padded monotonic `seq` string (e.g. `"000001"`) so default lex order == insertion order. <!-- orianna: ok -->

### 4.2 SessionStatus normalization (locked per Q5)

Canonical enum — matches PR #40 `reference/1-content-gen.yaml` <!-- orianna: ok — company-os reference spec; see §1.3 suppressor -->: <!-- orianna: ok -->

```
configuring | building | built | qc_passed | qc_failed | build_failed | completed | cancelled
```

Mapping for backfill (locked per Q1 for `archived`):

| Old | New | Rule |
|---|---|---|
| `configuring` | `configuring` | identity |
| `approved` | `configuring` | state dropped; approve is now a transient UI action, not a persisted status |
| `building` | `building` | identity |
| `complete` | `completed` | spelling normalized |
| `failed` | `build_failed` | all current `failed` rows are factory failures |
| `archived` + `outputUrls` non-null | `completed` | user finished and closed |
| `archived` + `outputUrls` null | `cancelled` | user cancelled mid-flow |

### 4.3 Allowed status transitions

```
configuring  → building | cancelled
building     → built | build_failed | cancelled
built        → qc_passed | qc_failed
qc_failed    → configuring | cancelled
qc_passed    → completed
build_failed → configuring | cancelled
```

Enforced inside `transition_status` (CAS + validation). Illegal transitions raise; callers handle.

## 5. HTTP surface (existing Service 1 routes)

No new routes. Align these existing routes to PR #40 `reference/1-content-gen.yaml` <!-- orianna: ok — company-os reference spec; see §1.3 suppressor --> as follow-up work (outside the `session_store.py` extraction PRs): <!-- orianna: ok -->

| Route | Source | Status vs spec |
|---|---|---|
| `POST /session/new` | `main.py:1160` | Body shape drift (see §1.3); needs `languages`, `shortcode`; drop `insuranceLine`, `closeSessionId` (closeSessionId should be a separate `POST /session/{id}/close` call) |
| `POST /session` | `main.py:1238` | Not in spec. Either spec it (internal variant) or merge into `/session/new` with auth discrimination |
| `GET /session/{id}` | `main.py:1341` (HTML) | Matches spec (`getStudioUi`) |
| `GET /session/{id}/status` | `main.py:1454` | Response shape drift; align to `SessionSummary`-adjacent fields in spec |
| `POST /session/{id}/approve` | `main.py:1482` | **Delete.** No `approved` state in spec |
| `POST /session/{id}/build` | `main.py:1551` | Matches spec |
| `POST /session/{id}/cancel-build` | `main.py:2084` | Not in spec. Propose adding |
| `POST /session/{id}/complete` | `main.py:2158` | Not in spec. Propose adding (or fold into PATCH) |
| `POST /session/{id}/close` | `main.py:2179` | Not in spec. Propose adding (sets `cancelled`) |
| `GET /sessions` | `main.py:2039` | Paginate: cursor-based per Q2; spec currently says `limit+offset` → **spec drift flag** |
| `GET /session/{id}/history` | `main.py:1980` | Now reads subcollection; response shape should match spec |

See §6.3 for the consolidated drift list sent to the API team.

## 6. Migration plan — phased, low-risk, no cutover window

Each phase is an independently mergeable PR. No service moves, no data moves — only internal refactor.

### 6.1 Phase A — Introduce `session_store.py` <!-- orianna: ok --> (additive)

<!-- orianna: ok — session_store.py, session.py, main.py, auth.py, factory_bridge.py, factory_bridge_v2.py, dashboard_service.py, phase.py in this section are company-os files under missmp/company-os/tools/demo-studio-v3/ -->

- Create `session_store.py` <!-- orianna: ok -->. Implement every function in §3 against the existing `demo-studio-sessions` collection. Preserve the current document shape (no schema change yet).
- Add a typed `Session` dataclass; existing call sites still work off raw dicts at this phase — `session_store` <!-- orianna: ok --> accepts both and returns a dict view through a `to_dict()` for compatibility.
- Unit tests mock `session_store` <!-- orianna: ok --> module, not Firestore.
- No call-site changes. Old `session.py` <!-- orianna: ok --> stays. **Safe to merge alone.**

**Estimate:** 90 min.

### 6.2 Phase B — Migrate call sites

Swap every direct-Firestore call and every `session.py` <!-- orianna: ok --> import to `session_store.py` <!-- orianna: ok -->.

- `main.py` <!-- orianna: ok -->: remove the `session` imports at line 36; replace `get_db()` at lines 80, 247, 2043; remove the inline `from google.cloud import firestore` at line 2046.
- `auth.py` <!-- orianna: ok -->: delete `_get_db()`; re-wire `verify_and_consume_token` to `session_store.try_consume_token(...)` (tokens still Firestore-backed at this phase — the in-process cache lands in Phase D).
- `factory_bridge.py` <!-- orianna: ok --> / `factory_bridge_v2.py` <!-- orianna: ok -->: swap `update_session_status`, `update_session_field` for `session_store.update_session(...)` / `session_store.transition_status(...)`.
- `dashboard_service.py` <!-- orianna: ok -->: swap `list_recent_sessions()` for `session_store.list_sessions(...)`.
- Delete `session.py` <!-- orianna: ok --> (its public names are re-exported from `session_store` <!-- orianna: ok --> during a short deprecation window, then removed).

**Estimate:** 2–3 hours including test updates (bulk rename in ~15 test files; the mock target shifts from `session.get_db` to `session_store.<fn>`).

### 6.3 Phase C — Status-enum migration (one-shot script)

- Script: `company-os/tools/demo-studio-v3/scripts/migrate_session_status.py` <!-- orianna: ok — future company-os script file under missmp/company-os/tools/demo-studio-v3/scripts/ -->. <!-- orianna: ok -->
- Reads every doc in `demo-studio-sessions`. Applies the §4.2 mapping. Writes back in place. Dry-run mode first.
- Handles `approved` → `configuring`, `complete` → `completed`, `failed` → `build_failed`, `archived` → `completed` or `cancelled` per heuristic.
- Backfill report: counts per old→new pair, plus any rows the heuristic couldn't resolve.
- `session_store.transition_status` is bypassed during migration (direct Firestore write within `session_store` — this is the only "migration escape hatch" in the module).

**Estimate:** 45 min script + dry-run review.

### 6.4 Phase D — Auth tokens move to in-process TTL cache

- `session_store.try_consume_token` backing flips from Firestore to an in-process TTL dict (size-capped, TTL = 1 hour per existing `TOKEN_EXPIRY`).
- Tokens are one-shot + time-bound. The single-instance Cloud Run footprint and token TTL make a cross-instance store unnecessary (confirmed Q4 lock).
- Delete the `demo-studio-used-tokens` Firestore collection.
- `session_store` no longer touches that collection reference.

**Estimate:** 45 min.

**Trade-off noted:** if Service 1 scales to >1 instance, a token minted on one instance cannot be consumed on another. Mitigation path is a shared Memcache/Redis layer, not Firestore. Acceptable now given the instance count (1) and token usage pattern (immediate redeem).

### 6.5 Phase E — Camille audit (grep gate)

CI gate: fail the build if any file under `company-os/tools/demo-studio-v3/` <!-- orianna: ok — grep-gate scope string referring to missmp/company-os; not a local filesystem path --> other than `session_store.py` imports `google.cloud.firestore` (string match `from google.cloud import firestore` or `import google.cloud.firestore`). <!-- orianna: ok -->

- Permits exactly one occurrence, tagged with `# azir: boundary`.
- Runs on every PR.

**Camille advisory (2026-04-21) — grep-gate pattern hardening** (ref: `assessments/advisory/2026-04-21-mad-grep-gate-allowlist-advisory.md`):

The literal `config_mgmt_client` token grep catches the happy path only. The gate must also scan for symbol-level bypass vectors:

1. **`from config_mgmt_client import <symbol>` patterns** — a bare `from ... import fetch_config` call does not contain the `config_mgmt_client` token at the call site and defeats a literal-only grep. The gate must include a secondary grep covering the public symbols exported by `config_mgmt_client` (`fetch_config`, `fetch_schema`, `patch_config`, and any additions to that surface).
2. **Star imports banned** — `from config_mgmt_client import *` is unconditionally forbidden under `tools/demo-studio-v3/`; the gate exits non-zero on any star-import from that module. <!-- orianna: ok -->
3. **Non-literal `importlib` banned** — `importlib.import_module(variable)` (where the argument is not a string literal) defeats static grep entirely; the gate must flag any `importlib.import_module` call whose argument is not a compile-time string literal under `tools/demo-studio-v3/`. <!-- orianna: ok -->

Upgrade path: when SE.E.2 graduates, replace the grep with a 30-line `ast.Import`/`ast.ImportFrom` walker that enforces all three rules at the AST level. <!-- orianna: ok -->

**Estimate:** 15 min (gate script) + advisory review.

## 7. Consequences

- Service 1 stays Firestore-bound — by choice. The ownership model is clean: our team's state, on our team's service.
- Every Firestore access is behind a typed, testable Python API. Tests mock the module, not the client.
- `session.py` <!-- orianna: ok --> disappears; `session_store.py` <!-- orianna: ok --> replaces it and expands (adds events, tokens, listing).
- Service 2 sees zero change. Config API team is not blocked, not coordinated with, not asked for anything.
- `configVersion` remains a pointer that Service 2 owns on write (via Config API). `session_store` <!-- orianna: ok --> exposes it read-only to callers.
- Test suite shrinks: the ~15 files patching `session.get_db` collapse to a single `session_store` <!-- orianna: ok --> fake.
- Rollback per phase is a straight revert — no data migration except Phase C (which is idempotent on re-run against the new enum).

## 8. Non-goals (explicit)

- **NOT** moving sessions to Service 2.
- **NOT** adding any endpoint to Service 2.
- **NOT** changing the Config API contract.
- **NOT** removing Firestore from Service 1.
- **NOT** introducing new secrets. `SESSION_SECRET` and `INTERNAL_SECRET` already exist and are unchanged. `CONFIG_MGMT_TOKEN` is untouched and unrelated.

## 9. Handoff

- **Kayn / Aphelios:** decompose §6.1–§6.5 into TDD task pairs. Phase A is test-first on the new module (Firestore emulator or in-memory fake). Phase B test updates are mostly mock-target renames; watch for the few tests that assert on Firestore call shapes and rewrite them to assert on `session_store` <!-- orianna: ok --> calls.
- **Camille:** own the Phase E grep gate. Two-line CI check.
- **API team (via Sona):** see §1.3 / §5 / §6.3 spec drift flags. The big items: delete `approved` everywhere, align `/session/new` body, decide pagination style on `/sessions` (ADR recommends cursor; spec says offset), and spec the currently-unspecified routes (`/session`, `/cancel-build`, `/complete`, `/close`).
- **Heimerdinger:** no ops change. No new service, no new secret, no new env var. One Firestore index to confirm exists: `demo-studio-sessions` on `(status ASC, createdAt DESC)` for the `list_sessions` path.

## Tasks

_Source: `company-os/plans/2026-04-20-session-state-encapsulation-tasks.md` in `missmp/company-os`. Inlined verbatim._ <!-- orianna: ok — future task file in missmp/company-os --> <!-- orianna: ok -->

**ADR:** `plans/approved/work/2026-04-20-session-state-encapsulation.md`
**Branch:** `feat/demo-studio-v3` <!-- orianna: ok -->
**Repo:** `missmp/company-os`, all work under `tools/demo-studio-v3/` <!-- orianna: ok — all tools/demo-studio-v3/ refs in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
**TDD:** `company-os/.github/workflows/tdd-gate.yml` <!-- orianna: ok — future CI workflow in missmp/company-os; not a local strawberry-agents file --> is active — every implementation task must be preceded on the same branch by an xfail test commit referencing the task ID. Pre-push hook enforces; agents may never bypass. <!-- orianna: ok -->

### Scope and sequencing rationale

This decomposition turns ADR §6.1–§6.5 into pairwise TDD tasks (xfail test → impl) plus one enum backfill and one CI grep gate. The only HTTP-surface work included is the delete-of-`/session/{id}/approve` route that falls out of the `approved` enum retirement — all other spec-drift items from §5 are captured as follow-up tasks (`SE.F.*`) sequenced **after** the extraction lands.

This ADR must land before `plans/in-progress/work/2026-04-20-managed-agent-lifecycle.md` <!-- orianna: ok — MAL is being re-signed and promoted to in-progress in the same recovery session; path is correct post-promotion --> and `plans/in-progress/work/2026-04-20-managed-agent-dashboard-tab.md`. Both siblings consume the terminal-status set `{completed, cancelled, qc_failed, build_failed, built}` from §4.3 and both call `session_store.transition_status(...)` for their teardown hooks. Shipping the enum migration first reduces the blast radius — surface area is still small on `feat/demo-studio-v3`. <!-- orianna: ok -->

### Task ID scheme

- `SE.0.*` — preflight (audit + Firestore index check)
- `SE.A.*` — Phase A: introduce `session_store.py` <!-- orianna: ok --> (ADR §6.1)
- `SE.B.*` — Phase B: migrate call sites (ADR §6.2)
- `SE.C.*` — Phase C: status-enum migration (ADR §6.3)
- `SE.D.*` — Phase D: auth tokens to in-process TTL (ADR §6.4)
- `SE.E.*` — Phase E: Camille grep gate (ADR §6.5)
- `SE.F.*` — follow-up HTTP-spec alignment (ADR §5 / §6.3) — out of extraction-PR scope

Sub-letters (`SE.A.1a`, `SE.A.1b`) reserved for amendments within a step. Test commits carry the suffix `-test` in commit messages and reference the impl task ID they unblock. <!-- orianna: ok -->

---

### SE.0 — Preflight

#### SE.0.1 — Audit current Firestore touchpoints
- **What:** Produce a one-page inventory of every line that touches Firestore today: imports, `get_db()` calls, transactional blocks, collection names, field writes. Check against ADR §1.1.
- **Where:** write report to `tools/demo-studio-v3/docs/session-store-audit.md`. <!-- orianna: ok — future artefact in missmp/company-os; does not exist yet --> <!-- orianna: ok -->
- **Why:** ADR §1.1 is 2026-04-20-accurate but the line numbers drift with every commit. Rebaselining before Phase A starts prevents call-site work from missing a site.
- **Acceptance:** the report enumerates every `from google.cloud import firestore` and `session.get_db` call currently on `feat/demo-studio-v3`; grep produces no new matches not in the report. <!-- orianna: ok -->
- **TDD:** exempt — audit artefact, no code change.
- **Depends on:** none.

#### SE.0.2 — Confirm Firestore composite index for list_sessions
- **What:** verify (or create, via gcloud) the `demo-studio-sessions` composite index on `(status ASC, createdAt DESC)` in the current Firestore project. Document the index ID and region.
- **Where:** append to `tools/demo-studio-v3/docs/session-store-audit.md`. <!-- orianna: ok — same future artefact as SE.0.1 --> <!-- orianna: ok -->
- **Why:** ADR §9 Heimerdinger handoff requires this index for `session_store.list_sessions(status=..., cursor=...)`. Missing it will surface only at runtime when Phase B flips traffic.
- **Acceptance:** `gcloud firestore indexes composite list` output pasted with the matching index; or an index-create command recorded and run by Heimerdinger.
- **TDD:** exempt — infra confirmation, no code change.
- **Depends on:** none.

---

### SE.A — Phase A: introduce `session_store.py` <!-- orianna: ok --> (additive)

Merges independently. Old `session.py` <!-- orianna: ok --> still in place at end of phase.

#### SE.A.1 — xfail tests for `session_store` dataclasses and types
- **What:** write `tools/demo-studio-v3/tests/test_session_store_types.py` <!-- orianna: ok — company-os future test file --> asserting: `Session`, `SessionEvent`, `Page` are frozen dataclasses with the fields listed in ADR §3; `SessionStatus` is the exact 8-value `Literal` from §4.2 in order. <!-- orianna: ok -->
- **Where:** new test file.
- **Why:** locks the public shape before the impl starts.
- **Acceptance:** tests import `session_store` and fail because the module does not exist. Marked `@pytest.mark.xfail(reason="SE.A.2", strict=True)`.
- **TDD:** this is the xfail commit for SE.A.2.
- **Depends on:** SE.0.1.

#### SE.A.2 — Implement `session_store.py` <!-- orianna: ok --> dataclasses + module scaffold
- **What:** create `company-os/tools/demo-studio-v3/session_store.py` <!-- orianna: ok --> with the `Session` / `SessionEvent` / `Page` dataclasses, the `SessionStatus` `Literal`, and empty function stubs for every API in ADR §3 (`create_session`, `get_session`, `update_session`, `transition_status`, `list_sessions`, `append_event`, `get_events`, `try_consume_token`).
- **Where:** `tools/demo-studio-v3/session_store.py`. Exactly one `# azir: boundary` comment on the `from google.cloud import firestore` import. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §2.1 boundary rule — only place in Service 1 allowed to import `google.cloud.firestore`. <!-- orianna: ok -->
- **Acceptance:** SE.A.1 now passes (remove xfail marker). `grep -rn 'from google.cloud import firestore' company-os/tools/demo-studio-v3/` <!-- orianna: ok --> still shows existing call sites — this task does NOT remove them yet.
- **TDD:** preceded by SE.A.1.
- **Depends on:** SE.A.1.

#### SE.A.3 — xfail tests for `session_store.create_session` / `get_session`
- **What:** `test_session_store_crud.py` with Firestore mocks (pattern from existing `tests/test_session.py` <!-- orianna: ok — company-os test file under missmp/company-os/tools/demo-studio-v3/tests/ -->). Covers: new-session doc shape matches ADR §3 Session dataclass fields; `get_session` returns `Session | None`; `get_session` returns None when Firestore unavailable. <!-- orianna: ok -->
- **Where:** new test file, mirrors `tests/test_session.py` <!-- orianna: ok — company-os test file under missmp/company-os/tools/demo-studio-v3/tests/ --> style. <!-- orianna: ok -->
- **Why:** locks the Firestore doc shape before the write path is real.
- **Acceptance:** tests fail (stubs raise `NotImplementedError`); marked xfail/strict referencing SE.A.4.
- **TDD:** xfail commit for SE.A.4.
- **Depends on:** SE.A.2.

#### SE.A.4 — Implement `create_session` / `get_session` against existing collection
- **What:** body out `create_session` and `get_session` in `session_store.py` <!-- orianna: ok -->. Use the existing `demo-studio-sessions` collection.
  **BD amendment (Sona, 2026-04-20 s3 — see §2.1 of `2026-04-20-session-state-encapsulation-bd-amendment.md`):** the `Session` dataclass is **lifecycle-only** — `brand`, `market`, `languages`, `shortcode`, and `config_version` are NOT fields on `Session` and are NOT persisted to the session doc. Per BD-1 (strict, no denormalisation) and BD-3, identity fields live in S2 only; consumers fetch via `config_mgmt_client.fetch_config(session_id)`. Final field set: `session_id`, `created_at`, `updated_at`, `status`, `phase`, agent pointer (`managed_session_id` or whatever SE.A.2 named), `factory_run_id?`, `cancel_reason?`, plus the lifecycle fields already in SE.A.2 (`projectId?`, `outputUrls?`, `qcResult?`, `workerJobId?`, `archivedAt?`). The "preserve the current document shape" guidance from ADR §6.1 is **superseded** by BD-1 for the identity-field columns; the doc shape post-BD is the lifecycle subset only. Provide a `Session.to_dict()` back-compat view so legacy callers can keep reading raw dicts through Phase A — but the dict has no `brand`/`market`/`languages`/`shortcode`/`configVersion` keys. <!-- orianna: ok -->
- **Where:** `tools/demo-studio-v3/session_store.py`. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §6.1 additive step, as amended by BD §2.1 / §3.1.
- **Acceptance:** SE.A.3 passes (with the SE.A.3 fixture updated to drop the four identity fields + `configVersion`). `session.create_session` and `session_store.create_session` both still work against the same collection (dual-read tolerance for Phase A) — but `session_store.create_session` writes the lifecycle-only doc shape; legacy `session.create_session` continues to write its old shape until SE.B.2 deletes the call site.
- **TDD:** preceded by SE.A.3 (xfail fixture must be updated to the post-BD field set as part of the SE.A.4 commit pair).
- **Depends on:** SE.A.3.

#### SE.A.4b — `create_session` accepts agent-init metadata as pass-through (new, BD amendment)
- **What:** extend `session_store.create_session(...)` so it accepts `brand: str`, `market: str`, `languages: list[str]`, plus the optional slack fields (`slack_user_id?`, `slack_channel?`, `slack_thread_ts?`) as **function parameters** but does NOT persist any of them to Firestore. Return them alongside the new `Session` instance — recommended return type is a tuple `(Session, AgentInitMetadata)` or a struct/dataclass `CreateSessionResult { session: Session, agent_init: AgentInitMetadata }` (Kayn-recommended: the dataclass form for forward compatibility). `AgentInitMetadata` is a frozen dataclass holding the four (or seven, with slack) fields verbatim. The caller — `main.py` `/session/new` handler — forwards the metadata to the managed-agent boot context (per BD §5.1 target diagram). No Firestore write ever touches `brand`/`market`/`languages`/`shortcode`/slack fields. <!-- orianna: ok -->
  **Note on `shortcode`:** per BD amendment §3 (OQ-SE-2 SUPERSEDED by BD-1), `shortcode` is NOT in the agent-init metadata accepted at session creation. It does not appear in the `/session/new` body (see SE.F.1) and is not auto-generated by S1. The agent later sets it via `set_config` MCP → S2 if needed. `AgentInitMetadata` therefore omits `shortcode`.
- **Where:** `tools/demo-studio-v3/session_store.py` (function signature + return type), `tools/demo-studio-v3/tests/test_session_store_crud.py` (extend SE.A.3 fixture). <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** BD §2.2 + §5.1 — S1 is a pass-through for identity fields; persistence is S2's job (and only after the agent's first `set_config`).
- **Acceptance:** new test `test_create_session_returns_agent_init_metadata_unpersisted` asserts: (i) calling `create_session(brand="X", market="Y", languages=["en"])` returns `(Session, AgentInitMetadata)` with the metadata populated; (ii) the resulting Firestore-mocked write payload contains NONE of `brand`/`market`/`languages`/`shortcode`; (iii) `Session.to_dict()` likewise omits all four. Marked `@pytest.mark.xfail(reason="SE.A.4b", strict=True)` in the same xfail commit as SE.A.3, and unflakes when SE.A.4 + SE.A.4b land together.
- **TDD:** xfail-paired with SE.A.4 (single xfail commit covers both, per pre-push hook semantics — same convention SE.B.1 uses for SE.B.2 through SE.B.6).
- **Depends on:** SE.A.4 (same commit pair, but logically follows: extend signature once dataclass exists).

#### SE.A.5 — xfail tests for `update_session` field allowlist + `transition_status` CAS
- **What:** `test_session_store_mutations.py` <!-- orianna: ok — future test file, will exist after task SE.A.5 -->. Covers: (i) `update_session` rejects unknown fields (mirrors existing `test_session.py` <!-- orianna: ok — existing company-os test file under missmp/company-os/tools/demo-studio-v3/tests/ -->`::test_update_session_field_rejects_non_allowlisted`); (ii) `transition_status` returns True on legal CAS; (iii) returns False on stale `from_status`; (iv) raises on illegal transitions per ADR §4.3 table. <!-- orianna: ok -->
  **BD amendment (Sona, 2026-04-20 s3 — see §2.1 of amendment file):** any fixture in this test file that constructs a `Session` instance or a Firestore-mock doc payload MUST omit `brand`, `market`, `languages`, `shortcode`, and `config_version` — they are no longer fields. Update the `update_session` allowlist-rejection test to assert these five names are rejected as unknown fields (they were never allowlisted, but post-BD they are also not lifecycle fields, so explicit rejection regression-locks the boundary). `transition_status` signature is unchanged — confirm fixtures don't pass identity fields as kwargs.
- **Where:** new test file.
- **Why:** locks the mutation surface before the impl exists; BD amendment locks the lifecycle-only field set.
- **Acceptance:** tests fail at stubs; xfail/strict → SE.A.6. New explicit-rejection assertion: `update_session(sid, brand="X")` raises (or rejects with the same `_UPDATABLE_FIELDS`-style guard) for each of `{brand, market, languages, shortcode, config_version}`.
- **TDD:** xfail commit for SE.A.6.
- **Depends on:** SE.A.4, SE.A.4b.

#### SE.A.6 — Implement `update_session` + `transition_status`
- **What:** flesh out `update_session` (allowlist: `managedSessionId`, `projectId`, `factoryRunId`, `outputUrls`, `eventHistory`, `archivedAt`, `workerJobId`, `qcResult`, `cancelReason`) and `transition_status` (Firestore transactional CAS + ADR §4.3 validation).
  **Signature (OQ-MAL-6 / OQ-MAD-1 resolution — Sona 2026-04-21):** `transition_status(session_id, new_status, *, cancel_reason: str | None = None)`. When `cancel_reason` is not None, persist it as `cancelReason` on the session doc atomically with the status flip. When None, leave any existing `cancelReason` field unchanged. Kwarg is additive; all existing callers unaffected.
- **Where:** `tools/demo-studio-v3/session_store.py`. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §3.
- **Acceptance:** SE.A.5 passes.
- **TDD:** preceded by SE.A.5.
- **Depends on:** SE.A.5.

#### SE.A.7 — xfail tests for `list_sessions` cursor pagination
- **What:** `test_session_store_list.py` <!-- orianna: ok — future test file, will exist after task SE.A.7 -->. Covers: cursor-based reverse-chronological paging; `status=` filter returns only matching rows; opaque cursor round-trips; `next_cursor=None` when page < limit. Test mocks `db.collection().order_by().start_after().limit().stream()` chain. <!-- orianna: ok -->
- **Where:** new test file.
- **Why:** ADR §3 / §5 — cursor style (not offset); locked per Q2.
- **Acceptance:** tests fail at stub; xfail/strict → SE.A.8.
- **TDD:** xfail commit for SE.A.8.
- **Depends on:** SE.A.6.

#### SE.A.8 — Implement `list_sessions` (limit+offset pagination, lifecycle-only rows)
- **What:** implement listing using `limit + offset` per the OQ-SE-4 resolution (ADR concedes to spec). Each returned row is a **lifecycle-only** projection: `{sessionId, status, phase, createdAt, updatedAt}` — no `brand`, no `market`, no `shortcode`, no `configVersion`. Per BD amendment §2.3 + BD §3.2 line 2055–2065 (Delete from S1 / identity-field extraction): consumers that need identity context fan out to S2 (`config_mgmt_client.fetch_config(session_id)`) per row (N+1 cost accepted by BD-1). Optional lifecycle fields documented in BD §3.2 may also surface (`managedSessionId?`, `factoryRunId?`, `projectId?`); confirm with SE.B.5 (dashboard caller) which optional fields it actually consumes — bias toward the minimal set to avoid leaking implementation detail.
  **Note (Sona, 2026-04-20 s3):** the SE.A.7 xfail test fixture must update accordingly — drop cursor-based `start_after` mock chain assertions in favour of `db.collection().order_by().offset().limit().stream()`, and assert the per-row shape contains lifecycle fields only. The composite index from SE.0.2 (`status ASC, createdAt DESC`) still applies and is still required.
- **Where:** `tools/demo-studio-v3/session_store.py`; SE.A.7 test file fixture update. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §3, §5; BD amendment §2.3; OQ-SE-4 resolution.
- **Acceptance:** SE.A.7 passes against the lifecycle-only row shape and `limit+offset` mock chain.
- **TDD:** preceded by SE.A.7 (with the BD amendment shape change folded into the SE.A.7 xfail commit).
- **Depends on:** SE.A.7, SE.0.2 (index must exist).

#### SE.A.9 — xfail tests for `append_event` / `get_events` subcollection
- **What:** `test_session_store_events.py` <!-- orianna: ok — future test file, will exist after task SE.A.9 -->. Covers: zero-padded `seq` document-key ordering (ADR §4.1); `append_event` is monotonic under contention (mocked transaction); `get_events` returns insertion-order `SessionEvent` list with cursor paging. <!-- orianna: ok -->
- **Where:** new test file.
- **Why:** ADR §4.1 subcollection layout, Q3 lock.
- **Acceptance:** tests fail at stub; xfail/strict → SE.A.10.
- **TDD:** xfail commit for SE.A.10.
- **Depends on:** SE.A.6.

#### SE.A.10 — Implement `append_event` / `get_events` against subcollection
- **What:** implement subcollection writer with zero-padded 6-digit `seq` document keys and transactional `seq` allocation (read max, increment, write). Implement cursor-based reader.
- **Where:** `tools/demo-studio-v3/session_store.py`. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §4.1.
- **Acceptance:** SE.A.9 passes.
- **TDD:** preceded by SE.A.9.
- **Depends on:** SE.A.9.

#### SE.A.11 — xfail tests for `try_consume_token` — Firestore-backed path
- **What:** `test_session_store_tokens.py` <!-- orianna: ok — future test file, will exist after task SE.A.11 -->. Covers: first call returns True + records token hash; second call returns False; returns False when Firestore unavailable. This tests the **Phase A/B** behaviour (still Firestore-backed). The in-process TTL switchover is Phase D. <!-- orianna: ok -->
- **Where:** new test file.
- **Why:** ADR §6.2 keeps Firestore backing through Phase B; §6.4 flips it.
- **Acceptance:** tests fail at stub; xfail/strict → SE.A.12.
- **TDD:** xfail commit for SE.A.12.
- **Depends on:** SE.A.6.

#### SE.A.12 — Implement `try_consume_token` (Firestore-backed, temporary)
- **What:** implement `try_consume_token` against `demo-studio-used-tokens` using the same transactional pattern from `auth.py` <!-- orianna: ok -->`::verify_and_consume_token`. Delete path deferred to SE.D.
- **Where:** `tools/demo-studio-v3/session_store.py`. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §6.2 — this function exists in Phase A so that `auth.py` <!-- orianna: ok --> can switch to it in Phase B before the Phase D cutover.
- **Acceptance:** SE.A.11 passes.
- **TDD:** preceded by SE.A.11.
- **Depends on:** SE.A.11.

---

### SE.B — Phase B: migrate call sites

After Phase A merges, every Firestore touchpoint outside `session_store.py` <!-- orianna: ok --> moves to the module boundary. Can be parallelised per file after SE.B.1.

#### SE.B.1 — xfail tests asserting call-site rewrites
- **What:** `test_call_site_boundary.py`. Covers: (i) `main.py` <!-- orianna: ok — company-os file --> no longer imports `from session import ...` or `from google.cloud import firestore`; (ii) `auth.py` <!-- orianna: ok — company-os file --> no longer imports from `session`; (iii) `factory_bridge.py` <!-- orianna: ok — company-os file --> / `factory_bridge_v2.py` <!-- orianna: ok — company-os file --> import only from `session_store`; (iv) `dashboard_service.py` <!-- orianna: ok — company-os file --> imports only from `session_store`. Pure `ast.parse` + import-grep test — no runtime. <!-- orianna: ok -->
- **Where:** new test file.
- **Why:** mechanical assertion so reviewers don't have to grep by hand, and so regressions fail CI.
- **Acceptance:** tests fail on current code; xfail/strict → SE.B.2.
- **TDD:** xfail commit for SE.B.2 through SE.B.6 collectively (one xfail covers a spread of impl commits per pre-push hook semantics).
- **Depends on:** SE.A.2.

#### SE.B.2 — Migrate `main.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ --> to `session_store` <!-- orianna: ok -->
- **What:** replace `from session import create_session, get_session, get_db, transition_session_status, update_session_field, update_session_status` with `import session_store`. Replace every call. Replace the inline `from google.cloud import firestore as _fs` at line 2046 by moving that query into `session_store.list_sessions(status=None, limit=..., offset=...)` (signature per SE.A.8 post-OQ-SE-4). Remove the `_check_firestore()` / `healthz` direct `get_db()` checks by adding a `session_store.healthcheck()` helper.
  **BD amendment (Sona, 2026-04-20 s3 — see §2.5 of amendment file + BD §3.2):** every identity-field read on `main.py` <!-- orianna: ok — company-os file --> MUST route to S2 via `config_mgmt_client.fetch_config(session_id)`, NOT to the session doc. Specifically: <!-- orianna: ok -->
  - `main.py:1349` <!-- orianna: ok — company-os file line ref --> `session_page` brand-in-title — replace `session.get("config", {}).get("brand", ...)` with `config_mgmt_client.fetch_config(session_id).config.get("brand", "New Session")`. Catch `NotFoundError` (cold session, pre-first-`set_config`) and fall back to "New Session". (BD §3.2 row 1349 — Refactor-to-S2-API-call.)
  - `main.py:1395–1397` <!-- orianna: ok — company-os file line ref --> `chat` lazy-create title derivation — same treatment; brand/market come from S2; `insuranceLine` is removed entirely (not in S2 schema). (BD §3.2 row 1395–1397.)
  - `main.py:1461–1472` <!-- orianna: ok — company-os file line ref --> `session_status` — drop `brand`/`market`/`shortcode`/`logos`/`configVersion` from response. Response is lifecycle-only. (Detailed shape rewrite is SE.F.3 — this task only ensures `main.py` <!-- orianna: ok — company-os file --> no longer reads those keys off the session doc.) (BD §3.2 row 1461–1472.) <!-- orianna: ok -->
  - `main.py:1987–2001` <!-- orianna: ok — company-os file line ref --> `session_history` summary — same treatment; brand for summary fetched from S2 on render. (BD §3.2 row 1987–2001.)
  - `main.py:2055–2065` <!-- orianna: ok — company-os file line ref --> `list_sessions` route — relies entirely on lifecycle-only rows from `session_store.list_sessions` (per SE.A.8 amended); no per-row identity-field projection in this route. Identity-field fan-out (if any caller needs it) is client-side or in SE.F.5 follow-up.
  Routes that BD §3.2 marks **Delete from S1** (preview at lines 1439–1445; `SAMPLE_CONFIG` plumbing at lines 53/1190/1192/1196–1201/1250–1254/1284) are NOT this task's responsibility — they are Aphelios's BD task scope per the BD ADR §3.14 Delete list. SE.B.2 limits itself to the boundary migration plus the four Refactor-to-S2 reads above.
  Add `import config_mgmt_client` at the top of `main.py` <!-- orianna: ok — company-os file --> (already present? grep before adding). <!-- orianna: ok -->
- **Where:** `tools/demo-studio-v3/main.py`, `tools/demo-studio-v3/session_store.py` (add `healthcheck()`). <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §6.2, §2.1 boundary; BD §2 Rule 2 (integration rule — identity reads via `config_mgmt_client.fetch_config`).
- **Acceptance:** `test_call_site_boundary` passes for `main.py` <!-- orianna: ok -->. Existing route-level tests pass after mock-target rename. New assertion in SE.B.1 boundary test (or paired with SE.B.2): `grep -n 'session.*\.get("config"' company-os/tools/demo-studio-v3/main.py` <!-- orianna: ok --> returns 0 matches on the four Refactor paths after this lands.
- **TDD:** preceded by SE.B.1.
- **Depends on:** SE.B.1, SE.A.2 through SE.A.12.

#### SE.B.3 — Migrate `auth.py` <!-- orianna: ok --> to `session_store.try_consume_token`
- **What:** delete `_get_db()` from `auth.py` <!-- orianna: ok -->`24-27`. Replace the `verify_and_consume_token` Firestore block with `session_store.try_consume_token(token_hash, ttl_seconds=TOKEN_EXPIRY)`. Remove the lazy `from session import get_db` import and the inline `from google.cloud.firestore import transactional`.
- **Where:** `tools/demo-studio-v3/auth.py`. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §6.2; also sets up the Phase D TTL-cache flip (backing changes inside `session_store`, not `auth.py` <!-- orianna: ok -->).
- **Acceptance:** `test_call_site_boundary` passes for `auth.py`; `tests/test_auth.py` <!-- orianna: ok — company-os test file under missmp/company-os/tools/demo-studio-v3/tests/ --> passes (mock target moves from `session.get_db` to `session_store.try_consume_token`). <!-- orianna: ok -->
- **TDD:** preceded by SE.B.1.
- **Depends on:** SE.B.1, SE.A.12.

#### SE.B.4 — Reduce `factory_bridge.py` <!-- orianna: ok --> / `factory_bridge_v2.py` <!-- orianna: ok --> to thin pass-through (mostly deletion)
- **What:** **BD amendment (Sona, 2026-04-20 s3 — see §4 item 6 of amendment file + BD §3.3, §3.4, §3.14):** the original SE.B.4 scope (boundary migration + enum rename) collapses to mostly **deletion**, because BD §3.14 Delete-from-S1 list removes nearly all of factory_bridge*'s code surface. The post-BD shape of each `trigger_factory*` function is a thin pass-through: read session, POST `/build {sessionId}` to S3, write `factoryRunId`. Concrete delete list includes `factory_bridge.map_config_to_factory_params`, `factory_bridge._build_content_from_config`, `factory_bridge_v2.prepare_demo_dict`, `factory_v2/validate_v2.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/factory_v2/ --> (entire file), `sample-config.json` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ --> (entire file), plus all config-fetch + translation blocks in `trigger_factory*`. Keep + rewrite only the boundary-migration sliver. <!-- orianna: ok -->
- **Where:** `tools/demo-studio-v3/factory_bridge.py`, `tools/demo-studio-v3/factory_bridge_v2.py`, `tools/demo-studio-v3/factory_v2/validate_v2.py` (deleted), `tools/demo-studio-v3/sample-config.json` (deleted). <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §6.2 boundary + §4.2 enum renames; BD §2 Rule 1, Rule 2, §3.14 Delete-from-S1 list.
- **Acceptance:** `test_call_site_boundary` passes for both bridge files. New assertions: deleted symbols are absent from the codebase. `validate_v2.py` <!-- orianna: ok --> and `sample-config.json` <!-- orianna: ok --> no longer exist.
- **TDD:** preceded by SE.B.1.
- **Depends on:** SE.B.1, SE.B.2, SE.A.12.

#### SE.B.5 — Migrate `dashboard_service.py` <!-- orianna: ok --> and `phase.py` <!-- orianna: ok -->
- **What:** swap `list_recent_sessions` for `session_store.list_sessions(...)` in `dashboard_service.py` <!-- orianna: ok -->. In `phase.py` <!-- orianna: ok -->`27`, replace `main.update_session_field` with `session_store.update_session`.
- **Where:** `tools/demo-studio-v3/dashboard_service.py`, `tools/demo-studio-v3/phase.py`. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §6.2.
- **Acceptance:** `test_call_site_boundary` passes for both files. `tests/test_dashboard_service.py` <!-- orianna: ok — company-os test file under missmp/company-os/tools/demo-studio-v3/tests/ --> and `tests/test_phase.py` <!-- orianna: ok — company-os test file under missmp/company-os/tools/demo-studio-v3/tests/ --> pass. <!-- orianna: ok -->
- **TDD:** preceded by SE.B.1.
- **Depends on:** SE.B.1.

#### SE.B.6 — Bulk mock-target rename in legacy test files
- **What:** mechanical rename across all tests currently patching `session.get_db` or `main.update_session_status` / `main.update_session_field` / `main.transition_session_status`. New targets: `session_store.<fn>` or `main.session_store.<fn>` as the call-site dictates. Target files: `tests/conftest.py` <!-- orianna: ok — company-os test files under missmp/company-os/tools/demo-studio-v3/tests/ -->, `tests/test_sse_server_l1.py` (15 occurrences), `tests/test_preview.py` (11 occurrences), `tests/test_integration.py`, `tests/test_integration_l3.py`, `tests/test_session.py`, `tests/test_tdd_issues.py`, `tests/test_routes.py`. <!-- orianna: ok -->
- **Where:** `tools/demo-studio-v3/tests/*.py`. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §6.2 last bullet — the mock target shifts from `session.get_db` to the module.
- **Acceptance:** full pytest run green. `grep -rn 'session.get_db' tests/` returns zero results.
- **TDD:** this is test infrastructure; exempt from xfail-first per universal invariant 12.
- **Depends on:** SE.B.2 through SE.B.5.

#### SE.B.7 — Delete `session.py` (or convert to re-export shim) <!-- orianna: ok -->
- **What:** replace `tools/demo-studio-v3/session.py` <!-- orianna: ok — company-os file under missmp/company-os/tools/demo-studio-v3/ --> with a one-line re-export shim or delete the file outright. ADR §6.2 says "re-exported during a short deprecation window, then removed"; on this branch the short window is the PR review cycle. Recommend **delete** once SE.B.1 through SE.B.6 are green. <!-- orianna: ok -->
- **Where:** `tools/demo-studio-v3/session.py` (removed). <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §6.2 final bullet.
- **Acceptance:** `python -c 'import session'` raises `ModuleNotFoundError`; `test_call_site_boundary` still green.
- **TDD:** deletion-only change; SE.B.1 assertion already covers this.
- **Depends on:** SE.B.1, SE.B.2, SE.B.3, SE.B.4, SE.B.5, SE.B.6.

#### SE.B.8 — Delete `POST /session/{id}/approve` route and `approved` enum references
- **What:** remove the `approve()` handler in `main.py:1482` <!-- orianna: ok — company-os file line refs; main.py is under missmp/company-os/tools/demo-studio-v3/ --> and the `status not in ("approved", "configuring")` branch in `main.py:1565` <!-- orianna: ok — company-os file line ref -->. Update `build_session` to only accept `status == "configuring"` and call `session_store.transition_status(..., to_status="building")` directly. Update the archive-check in `/session/new` at line 1185 to use `to_status="cancelled"` instead of `"archived"`. Update `main.py:1473` <!-- orianna: ok — company-os file line ref --> `"archived": status == "archived"` to `"cancelled": status == "cancelled"` (or retire the field if dead; confirm with callers).
- **Where:** `tools/demo-studio-v3/main.py`. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §4.2 drops `approved`; §5 flags `POST /session/{id}/approve` as **Delete**; `/session/{id}/close` sets `cancelled` (not `archived`).
- **Acceptance:** grep `approved\|archived` in `main.py` <!-- orianna: ok — company-os file --> returns 0 non-comment hits. Affected test files renamed or updated. A fresh xfail test asserting the route is absent must precede this. <!-- orianna: ok -->
- **TDD:** preceded by SE.B.1 (boundary test) **plus** a fresh xfail test `test_approve_route_gone.py` <!-- orianna: ok — future test file, will exist after task SE.B.8 -->. <!-- orianna: ok -->
- **Depends on:** SE.B.2, SE.C.* (live migration) — do NOT merge this before SE.C.2 runs against prod.

---

### SE.C — Phase C: status-enum migration (one-shot)

#### SE.C.1 — Write `migrate_session_status.py` <!-- orianna: ok — future file, will exist after task SE.C.1 --> (dry-run default) <!-- orianna: ok -->
- **What:** create `company-os/tools/demo-studio-v3/scripts/migrate_session_status.py` <!-- orianna: ok — future company-os script file under missmp/company-os/tools/demo-studio-v3/scripts/ -->. Applies the ADR §4.2 mapping. Default mode is `--dry-run`. Prints a backfill report. <!-- orianna: ok -->
  **BD amendment (Sona, 2026-04-20 s3 — see §4 item 7 of amendment file):** the script touches the `status` field (and `cancelReason` for the unknown-status case) ONLY. The script must NOT inspect `brand`, `market`, `languages`, `shortcode`, `config`, or `configVersion`. The `--dry-run` report likewise reports counts on `status` only.
- **Where:** `tools/demo-studio-v3/scripts/migrate_session_status.py`. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §6.3; BD amendment §2.1 + §4 item 7.
- **Acceptance:** script runs green in `--dry-run` against a mocked-Firestore fixture with one row of each old status. Test fixture rows MAY contain `brand`/`market`/`config` keys (legacy shape) and the script must NOT read or write them.
- **TDD:** paired xfail `tests/test_migrate_session_status.py` <!-- orianna: ok — future test file, will exist after task SE.C.1 --> lands in the same or preceding commit. <!-- orianna: ok -->
- **Depends on:** SE.A.6.

#### SE.C.2 — Execute `--dry-run` against the live Firestore project
- **What:** run `python tools/demo-studio-v3/scripts/migrate_session_status.py --dry-run` against the real `demo-studio-sessions` collection. Capture the report as `assessments/2026-04-20-session-status-backfill-dryrun.md`. <!-- orianna: ok — future artefact in missmp/company-os assessments/ --> <!-- orianna: ok -->
  **BD amendment (Sona, 2026-04-20 s3):** the report enumerates status-field counts only. Unknown-legacy-status rows route automatically to `cancelled + cancelReason: "unknown_legacy_status"` (OQ-SE-1); no halt.
- **Where:** report file.
- **Why:** ADR §6.3 dry-run first; OQ-SE-1 resolution removes the halt.
- **Acceptance:** report committed.
- **TDD:** N/A — ops action.
- **Depends on:** SE.C.1.

#### SE.C.3 — Execute `--apply` and verify
- **What:** run `--apply` against live Firestore. Capture the apply report as `assessments/2026-04-20-session-status-backfill-apply.md`. <!-- orianna: ok — future artefact in missmp/company-os --> Verify with a post-check query. <!-- orianna: ok -->
  **BD amendment (Sona, 2026-04-20 s3):** the `--apply` writes `status` (and `cancelReason` for unknown-legacy rows) only — no other field is touched. Legacy `brand`/`market`/`config`/`configVersion` columns are LEFT IN PLACE on existing rows; they will be cleaned up separately by an Aphelios BD-deletion ops script.
- **Where:** report file.
- **Why:** ADR §6.3; BD amendment §4 item 7.
- **Acceptance:** apply report committed; verification query returns 0.
- **TDD:** N/A — ops action.
- **Depends on:** SE.C.2, SE.B.4. Strict order: SE.C.3 merges immediately before SE.B.8.

---

### SE.D — Phase D: auth tokens to in-process TTL cache

#### SE.D.1 — xfail tests for in-process token TTL
- **What:** `test_session_store_tokens_ttl.py` <!-- orianna: ok — future test file, will exist after task SE.D.1 -->. Covers: (i) first consume returns True; (ii) second consume returns False; (iii) consume after TTL expires returns True again; (iv) cache is size-capped (insert > cap, oldest evicted); (v) cache never touches Firestore. <!-- orianna: ok -->
- **Where:** new test file.
- **Why:** ADR §6.4, Q4 lock.
- **Acceptance:** tests fail against SE.A.12 Firestore-backed impl; xfail/strict → SE.D.2.
- **TDD:** xfail commit for SE.D.2.
- **Depends on:** SE.A.12.

#### SE.D.2 — Flip `try_consume_token` to in-process TTL cache
- **What:** replace the Firestore body of `try_consume_token` with a size-capped TTL dict. Size cap = 10 000 tokens; TTL = `TOKEN_EXPIRY` (60 min). Acquire a module-level `threading.Lock` around mutations. <!-- orianna: ok -->
- **Where:** `tools/demo-studio-v3/session_store.py`. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §6.4.
- **Acceptance:** SE.D.1 passes.
- **TDD:** preceded by SE.D.1.
- **Depends on:** SE.D.1.

#### SE.D.3 — Delete `demo-studio-used-tokens` Firestore collection
- **What:** one-line script `company-os/tools/demo-studio-v3/scripts/drop_used_tokens_collection.py` <!-- orianna: ok — future company-os script file under missmp/company-os/tools/demo-studio-v3/scripts/ --> that streams + deletes every document in the collection. Manual invocation post-SE.D.2 deploy. <!-- orianna: ok -->
- **Where:** script + ops action.
- **Why:** ADR §6.4.
- **Acceptance:** post-run the collection returns 0 docs. Captured in `assessments/2026-04-20-used-tokens-drop.md`. <!-- orianna: ok — future artefact in missmp/company-os --> <!-- orianna: ok -->
- **TDD:** N/A — ops action.
- **Depends on:** SE.D.2 deployed to prod.

---

### SE.E — Phase E: Camille grep gate

#### SE.E.1 — xfail test for grep-gate script
- **What:** `tests/test_firestore_boundary_gate.py` <!-- orianna: ok — company-os future test file under missmp/company-os/tools/demo-studio-v3/tests/ -->. Covers: the CI script detects a planted `from google.cloud import firestore` in a throwaway file under `tools/demo-studio-v3/` <!-- orianna: ok — company-os path; refers to missmp/company-os/tools/demo-studio-v3/ --> and exits non-zero; exits zero when only `session_store.py` has the import tagged `# azir: boundary`. <!-- orianna: ok -->
- **Where:** new test file + a throwaway fixture module.
- **Why:** ADR §6.5.
- **Acceptance:** test fails because the gate script does not exist yet; xfail/strict → SE.E.2.
- **TDD:** xfail commit for SE.E.2.
- **Depends on:** SE.B.7.

#### SE.E.2 — Implement grep-gate script + CI wiring
- **What:** bash script `company-os/scripts/ci/firestore-boundary-gate.sh` <!-- orianna: ok — future company-os CI script under missmp/company-os/scripts/ci/; not a local strawberry-agents script --> that grep-scans `company-os/tools/demo-studio-v3/*.py` <!-- orianna: ok — company-os glob pattern under missmp/company-os/; not a local filesystem path --> and fails if any file other than `session_store.py` contains `from google.cloud import firestore` or `import google.cloud.firestore`. Wire into `.github/workflows/` <!-- orianna: ok — company-os workflow directory under missmp/company-os/.github/workflows/ -->. <!-- orianna: ok -->
  **BD amendment (Sona, 2026-04-20 s3 — see §4 item 8 of amendment file + BD §2 Rule 4):** the gate script extends to two additional patterns:
  1. **`config_mgmt_client` import scope.** Disallow outside an explicit allowlist of files. Allowlist (cumulative across all BD amendments): `main.py`, `factory_bridge*.py` handful, `managed_session_monitor.py`, dashboard handler for `GET /api/managed-sessions`. Gate exception convention: `# azir: config-boundary` comment on the import line. <!-- orianna: ok -->
  2. **`insuranceLine` literal ban.** Disallow the literal string `insuranceLine` anywhere under `tools/demo-studio-v3/` <!-- orianna: ok — scope reference to missmp/company-os/tools/demo-studio-v3/; not a local filesystem path --> (excluding `tests/` for legacy fixtures and migration scripts). <!-- orianna: ok -->
- **Where:** `scripts/ci/firestore-boundary-gate.sh` <!-- orianna: ok — future CI script in missmp/company-os, not this repo -->, `.github/workflows/firestore-boundary.yml` <!-- orianna: ok — future workflow file in missmp/company-os -->, `tools/demo-studio-v3/tests/test_firestore_boundary_gate.py` <!-- orianna: ok — company-os future test file --> (extended). <!-- orianna: ok -->
- **Why:** ADR §2.1 + §6.5; BD §2 Rule 4.
- **Acceptance:** SE.E.1 passes against all three pattern groups; the workflow is a required check.
- **TDD:** preceded by SE.E.1.
- **Depends on:** SE.E.1.

---

### SE.F — Follow-up HTTP-spec alignment (out of extraction PR scope)

#### SE.F.1 — Align `POST /session/new` body to spec
- **What:** **BD amendment (Sona, 2026-04-20 s3 — see §2.2 of amendment file + BD §5.1):** change body to `{brand, market, languages, slackUserId?, slackChannel?, slackThreadTs?}` — `shortcode` is **REMOVED ENTIRELY** from the body (per BD-1 strict; OQ-SE-2 is SUPERSEDED — no server-side auto-generation). Drop `insuranceLine` (BD §3.2 line 1192). Move `closeSessionId` to a separate `POST /session/{id}/close` call from the client.
  The four identity fields (`brand`, `market`, `languages` + slack triple) are **agent-init metadata only** — passed through S1 to the managed agent's boot context at launch time. S1 does NOT persist them on the session doc.
  **SE.F.1b (new, BD amendment):** Add an integration test asserting end-to-end `/session/new` behaviour.
- **Where:** `tools/demo-studio-v3/main.py` + caller(s) in Studio UI templates. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §1.3 + §5; BD amendment §2.2; BD §5.1.
- **Duong-blocker:** RESOLVED — OQ-SE-2 is SUPERSEDED by BD-1. `shortcode` is removed from the body entirely.
- **TDD:** xfail test on the new body shape precedes the impl.
- **Depends on:** SE.B.8, SE.A.4b.

#### SE.F.2 — Spec or remove `POST /session` (internal variant)
- **What:** merge the internal `POST /session` variant into `/session/new` with auth discrimination (per OQ-SE-3 resolution).
- **Where:** spec doc + handler change in `main.py:1238`.
- **Why:** ADR §5 row 2.
- **Duong-blocker:** OQ-SE-3 — RESOLVED. Merge path.
- **Depends on:** SE.F.1.

#### SE.F.3 — Align `GET /session/{id}/status` response to lifecycle-only shape
- **What:** **BD amendment (Sona, 2026-04-20 s3 — see §2.4 of amendment file + BD §3.2 row 1461–1472):** update response shape to **lifecycle-only**: `{sessionId, status, phase, createdAt, updatedAt, factoryRunId?}`. Drop ALL of: `brand`, `market`, `shortcode`, `logos` (per OQ-BD-2 RESOLVED), `configVersion` (per BD-3).
- **Where:** `tools/demo-studio-v3/main.py:1454`. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §1.3; BD amendment §2.4; BD §3.2 row 1461–1472; OQ-BD-2 resolution.
- **TDD:** xfail test on the response shape precedes impl.
- **Depends on:** SE.F.1, SE.B.2.

#### SE.F.4 — Spec `/cancel-build`, `/complete`, `/close`
- **What:** add these to PR #40 `reference/1-content-gen.yaml` <!-- orianna: ok — company-os reference spec under missmp/company-os/reference/; not a local filesystem path -->. Handoff to Sona / API team. <!-- orianna: ok -->
- **Why:** ADR §5.
- **Depends on:** none in this task list; hand-off item.

#### SE.F.5 — Reconcile `/sessions` response shape (rows = lifecycle-only)
- **What:** **BD amendment (Sona, 2026-04-20 s3 — see §2.3 of amendment file + BD §3.2 row 2055–2065):** the `/sessions` route returns rows shaped `{sessionId, status, phase, createdAt, updatedAt}` — strictly lifecycle. Drop `brand`, `market`, `shortcode`, `configVersion` from every row. Pagination mechanism is **`limit + offset`** per OQ-SE-4 RESOLVED.
- **Where:** `tools/demo-studio-v3/main.py:2039`. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §1.3 row 6, §5; BD amendment §2.3; OQ-SE-4 resolution.
- **Duong-blocker:** RESOLVED — OQ-SE-4 RESOLVED in favour of `limit+offset`.
- **TDD:** xfail test on the response row shape precedes impl.
- **Depends on:** SE.A.8, SE.B.5.

#### SE.F.6 — Align `GET /session/{id}/history` to subcollection-backed response
- **What:** once Phase A events subcollection exists (SE.A.10), `/session/{id}/history` reads from it rather than the embedded `eventHistory` field.
- **Where:** `tools/demo-studio-v3/main.py:1980`. <!-- orianna: ok — company-os file(s); all tools/demo-studio-v3/ paths in this Tasks section are in missmp/company-os --> <!-- orianna: ok -->
- **Why:** ADR §5 row 11, §4.1.
- **TDD:** xfail test asserting subcollection reads precedes the swap.
- **Depends on:** SE.A.10.

---

### Dispatch plan — critical path, parallelism, hard serial points

**Critical path (blocking spine):**

```
SE.0.1 → SE.A.1 → SE.A.2 → SE.A.3 → SE.A.4 → SE.A.5 → SE.A.6 → SE.B.1 → SE.B.2 → SE.C.1 → SE.C.2 → SE.C.3 → SE.B.8 → SE.E.1 → SE.E.2
```

**Hard serial points:**

1. **SE.C.3 immediately precedes SE.B.8.** The live `--apply` must convert every legacy-enum row before the code that recognises legacy values disappears.
2. **SE.A.2 must merge before any SE.B.* starts.**
3. **SE.D.3 must follow SE.D.2 deployed to prod**, not merged.
4. **SE.B.7 must follow SE.B.1 through SE.B.6.**

**Cross-ADR coupling:**

- The two sibling ADRs — `2026-04-20-managed-agent-lifecycle.md` <!-- orianna: ok — bare basename ref to sibling ADR; full path cited on line 349 --> and `2026-04-20-managed-agent-dashboard-tab.md` <!-- orianna: ok — bare basename ref to sibling ADR; full path cited on line 349 --> — both consume `session_store.transition_status` and the terminal-status set. They must **not** start their implementation phases before **SE.A.6** and **SE.C.3**. <!-- orianna: ok -->

---

### Open questions (Duong-blockers)

- **OQ-SE-1 — RESOLVED.** Accept default: rows with unknown legacy status migrate to `cancelled` with `cancelReason: "unknown_legacy_status"`.
- **OQ-SE-2 — RESOLVED, then SUPERSEDED by BD-1 (2026-04-20 s3).** `shortcode` is removed from the body entirely.
- **OQ-SE-3 — RESOLVED.** Merge the internal `POST /session` variant into `/session/new` with auth discrimination.
- **OQ-SE-4 — RESOLVED.** Spec wins: `GET /sessions` uses `limit + offset` pagination.
- **OQ-SE-5 — RESOLVED.** Accept default: `session_store.healthcheck()` mirrors today's behaviour — `collection('sessions').limit(1).get()`.

---

### Estimates

| Phase | Tasks | Estimate (person-hours) |
|---|---|---|
| SE.0 | 2 | 1.0 |
| SE.A | 12 (6 xfail + 6 impl) | 6.0 |
| SE.B | 8 | 5.0 |
| SE.C | 3 | 2.0 |
| SE.D | 3 | 1.5 |
| SE.E | 2 | 0.5 |
| SE.F | 6 | 4.0 (follow-up, separate PRs) |
| **Total extraction PRs (SE.0–SE.E)** | **30** | **~16 person-hours** |

**36 total tasks** (30 extraction + 6 follow-up HTTP-alignment).

## Test plan

Three layers, per the TDD gate active on `feat/demo-studio-v3`: <!-- orianna: ok -->

- **I1 — Firestore boundary isolation:** every xfail/impl pair in SE.A asserts `session_store.py` <!-- orianna: ok --> is the only module allowed to import `google.cloud.firestore`; SE.E.2 grep-gate enforces this in CI on every PR.
- **I2 — Session dataclass shape:** SE.A.1/A.2 lock the lifecycle-only `Session` field set; SE.A.3/A.4 assert the Firestore write payload contains no `brand`, `market`, `languages`, `shortcode`, or `configVersion` keys.
- **I3 — Status transition correctness:** SE.A.5/A.6 cover all legal transitions in ADR §4.3, assert illegal transitions raise, and assert `transition_status` CAS returns `False` on stale `from_status`.
- **I4 — Call-site boundary coverage:** SE.B.1 `test_call_site_boundary.py` <!-- orianna: ok — future test file, will exist after task SE.B.1 --> uses `ast.parse` to confirm `main.py` <!-- orianna: ok -->, `auth.py` <!-- orianna: ok -->, `factory_bridge*.py` <!-- orianna: ok -->, and `dashboard_service.py` <!-- orianna: ok --> no longer import `google.cloud.firestore`; full pytest run must be green after SE.B.6.

## Amendments

_Source: `company-os/plans/2026-04-20-session-state-encapsulation-bd-amendment.md` in `missmp/company-os`. Inlined verbatim._ <!-- orianna: ok — cross-repo amendment file; exists in missmp/company-os --> <!-- orianna: ok -->

**Date:** 2026-04-20 (s3)
**Author:** Sona (coordinator, fastlane edit)
**Scope:** names the sections of `plans/2026-04-20-session-state-encapsulation.md` <!-- orianna: ok — self-ref under company-os naming; this plan is at plans/proposed/work/ in this repo --> (and tasks in `plans/2026-04-20-session-state-encapsulation-tasks.md` <!-- orianna: ok — future task file in missmp/company-os -->) that change as a consequence of the §11 resolutions in `plans/in-progress/work/2026-04-20-s1-s2-service-boundary.md` (BD ADR). <!-- orianna: ok -->

### 1. Why this amendment exists

BD-1 (strict, no denormalisation) directly contradicts the session-state ADR's Session dataclass, which lists `brand`, `market`, `languages`, `shortcode` as session fields. BD-2, BD-3, BD-5 further shrink the S1 session doc and remove `configVersion` from the S1 surface. These cascade into SE ADR sections and several of the 36 decomposed tasks.

Rather than rewrite the SE ADR (which would invalidate Kayn's 36-task decomposition), this amendment names the specific sections/tasks that change and what the new shape is. The SE ADR itself is not edited. Kayn reads this amendment when issuing the task-file revision.

### 2. SE ADR sections affected

#### 2.1 Session dataclass (SE ADR §3 / SE.A.4)

**Before:** `Session` includes `brand: str`, `market: str`, `languages: list[str]`, `shortcode: str` as session-persisted fields.

**After:** those four fields are **removed** from `Session`. Session dataclass is pure lifecycle: `session_id`, `created_at`, `updated_at`, `status`, `phase`, agent pointer (e.g. `agent_session_id` or whatever SE.A.4 names), `factory_run_id` (optional), `cancel_reason` (optional, per SE.C.1 resolution), and any other already-clean lifecycle fields SE.A.4 defined. No `config_version` either (per BD-3).

**Task impact:** SE.A.4 rewrite — drop 4 fields, drop `config_version`. SE.A.5 transition-status tests may reference those fields in fixtures; update. SE.A.6 `transition_status` signature unchanged.

#### 2.2 `POST /session/new` request body (SE ADR §1.3 / SE.F.1)

**Before (SE.F.1 target shape):** `{brand, market, languages, shortcode, slackUserId?, slackChannel?, slackThreadTs?}` — all persisted on the session doc.

**After:** `{brand, market, languages, slackUserId?, slackChannel?, slackThreadTs?}` are **agent-init metadata only** — passed through S1 to the managed agent's boot context at launch time. S1 does **not** persist them on the session doc. Shortcode is removed from the body entirely (BD-1 strict; reconciled with the moot OQ-SE-2 resolution below).

Net body shape: `{brand, market, languages, slackUserId?, slackChannel?, slackThreadTs?}`.

**Task impact:** SE.F.1 rewrites. No Firestore write for `brand/market/languages/shortcode` in `session_store.create_session`. <!-- orianna: ok -->

#### 2.3 `/sessions` list response (SE ADR §1.3 / SE.F.5 / OQ-SE-4)

**Before:** list rows include `brand`, `market`, `shortcode`, `configVersion` alongside lifecycle fields.

**After:** list rows are lifecycle-only — `{sessionId, status, phase, createdAt, updatedAt}`. No brand/market/shortcode/configVersion. Callers that need identity fields call S2 per session (accepted N+1 cost per BD-1). Pagination style remains `limit+offset` per OQ-SE-4 resolution.

**Task impact:** SE.A.8 (list_sessions pagination xfail) test shape updates. SE.F.5 response-shape amendment.

#### 2.4 `GET /session/{id}/status` response (SE ADR §1.3 / SE.F.3)

**Before (SE.F.3 target):** aligns with `SessionSummary` — included `brand`, `market`, `shortcode`, `configVersion`, `status`, createdAt/updatedAt.

**After (BD-2 + BD-3):** drop `logos` (confirmed via BD-2), drop `brand/market/shortcode/configVersion` (BD-1 strict + BD-3). Response is lifecycle-only: `{sessionId, status, phase, createdAt, updatedAt, factoryRunId?}`. <!-- orianna: ok -->

**Task impact:** SE.F.3 rewrites. Xfail test (`SE.F.3-xfail`) asserts the new shape.

#### 2.5 `configVersion` (SE ADR §3 / §4.1)

**Before:** `configVersion` planned as a session field (monotonic int pointer mirrored from S2 on every write).

**After:** **removed from S1 entirely.** S3 `/build` reads the latest version from S2 directly. Preview (iframe to S5) does its own version resolution. No S1 consumer needs `configVersion`.

**Task impact:** any task touching `configVersion` drops the reference.

#### 2.6 `eventHistory` subcollection (SE ADR §4.1 / SE.A.10)

**No change.** Event history is session-lifecycle data, not config. Stays on S1. SE.A.10 proceeds as decomposed.

### 3. OQ-SE resolutions affected

- **OQ-SE-2 (shortcode auto-generation) — SUPERSEDED by BD-1.** Shortcode is not on the session doc at all. Mark the SE-side resolution as superseded in the SE tasks file; do not implement server-side auto-generation in S1.
- **OQ-SE-1 (unknown-status backfill) — UNCHANGED.**
- **OQ-SE-3 (internal POST /session merge) — UNCHANGED.**
- **OQ-SE-4 (/sessions pagination) — UNCHANGED at the mechanism level** (`limit+offset`) but the response rows shrink per §2.3 above.
- **OQ-SE-5 (healthcheck semantics) — UNCHANGED.**

### 4. Task-file amendments Kayn must issue

1. **SE.A.4** — rewrite Session dataclass: drop `brand`, `market`, `languages`, `shortcode`, `config_version`. Update acceptance criteria.
2. **SE.A.4b (new)** — `session_store.create_session` accepts agent-init metadata as function parameters but does not persist them; returns them in a tuple or struct the caller forwards to the managed-agent launch.
3. **SE.A.5** — update transition-status tests if they referenced removed fields in fixtures.
4. **SE.A.8** — update `/sessions` list row shape in xfail test to lifecycle-only.
5. **SE.B.2** — when migrating `main.py` <!-- orianna: ok --> call sites, the identity-field reads must route to S2 (fetch from `config_mgmt_client.fetch_config(session_id)`), not to the session doc.
6. **SE.B.4** — `factory_bridge*` call-site migration: since BD deletes translation entirely, most of SE.B.4's scope collapses to deletion rather than refactor.
7. **SE.C.1 / SE.C.2 / SE.C.3** — enum migration unchanged in mechanism, but the backfill dry-run no longer inspects `brand`/`market` fields.
8. **SE.E.2** — grep gate extended with two additional patterns per BD §2 Rule 4: (a) `config_mgmt_client` imports outside allowed-set; (b) `insuranceLine` literal anywhere in `tools/demo-studio-v3/` <!-- orianna: ok — scope reference to missmp/company-os/tools/demo-studio-v3/; not a local filesystem path -->. <!-- orianna: ok -->
9. **SE.F.1** — `/session/new` body revised per §2.2 above. Shortcode removed; remaining identity fields are agent-init metadata only.
10. **SE.F.3** — `/session/{id}/status` response revised per §2.4 above (lifecycle-only).
11. **SE.F.5** — `/sessions` response rows revised per §2.3 above.

### 5. Sequencing

Unchanged from BD §7. This amendment promotes with the BD ADR; both move to the approved state in a single `scripts/plan-promote.sh` <!-- orianna: ok — strawberry-agents repo script at scripts/plan-promote.sh; not a company-os path --> invocation. Kayn's task-file revision lands on `feat/demo-studio-v3` after promotion. <!-- orianna: ok -->

### 6. Out-of-scope for this amendment

- No changes to SE.0 (preflight), SE.A.1–3, SE.A.6, SE.A.7, SE.A.9–13, SE.D, SE.E.1, SE.F.2 / SE.F.4 / SE.F.6.
- No implementation guidance — this is a decision-reshape, not a task breakdown.

### 7. Handoff

- **Duong:** promote this file + BD ADR together via `scripts/plan-promote.sh`. Then invoke Kayn to revise the SE task file.
- **Kayn:** on Duong's signal, issue the task-file revision per §4 above. Write a "BD amendments (Sona, 2026-04-20 s3)" block at the end of `plans/2026-04-20-session-state-encapsulation-tasks.md` <!-- orianna: ok — future task file in missmp/company-os -->, plus inline edits. Commit with `chore:` prefix. <!-- orianna: ok -->
- **Orianna:** fact-check §2 claims against the SE ADR on `feat/demo-studio-v3` as part of the promotion gate. <!-- orianna: ok -->
- **Camille:** SE.E grep-gate will absorb the two new patterns when SE.E.2 decomposes post-promotion.

### 8. Decision log

- **OQ-MAL-6 / OQ-MAD-1 — RESOLVED — Sona 2026-04-21:** `transition_status` accepts `cancel_reason: str | None = None` as a keyword-only argument. Additive; no existing caller changes. See SE.A.6 signature note above.
