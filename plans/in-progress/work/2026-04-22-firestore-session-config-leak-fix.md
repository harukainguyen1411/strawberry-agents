---
status: in-progress
orianna_gate_version: 2
complexity: quick
concern: work
owner: karma
created: 2026-04-22
tags:
  - demo-studio-v3
  - firestore
  - bugfix
  - p0
  - work
tests_required: true
orianna_signature_approved: "sha256:11a3dade9bebefea151b542c59819ca6471a83775245d300720d31ffdff0849c:2026-04-22T09:15:31Z"
orianna_signature_in_progress: "sha256:11a3dade9bebefea151b542c59819ca6471a83775245d300720d31ffdff0849c:2026-04-22T09:16:56Z"
---

# P0 — Firestore session-doc config-leak fix (demo-studio-v3)

## Context

Investigation `assessments/work/2026-04-22-firestore-config-mgmt-leak-investigation.md`
(commit `b3729b0`) diagnosed that every one of the 96 session docs in the
`demo-studio-staging` Firestore DB carries a leaked full config payload. The
leak source is `create_session` (lines 38-52 in `mmp/workspace/tools/demo-studio-v3/session.py` <!-- orianna: ok -- path is in the mmp work workspace, not strawberry-agents -->)
which hard-codes `config`, `configVersion`, and `factoryVersion` onto every
new session doc. The BD-1-compliant module `mmp/workspace/tools/demo-studio-v3/session_store.py` <!-- orianna: ok -- path is in the mmp work workspace, not strawberry-agents -->
already exists; the bug is that `mmp/workspace/tools/demo-studio-v3/main.py` <!-- orianna: ok -- path is in the mmp work workspace, not strawberry-agents --> still imports the
pre-refactor `session.py` module. <!-- orianna: ok -- work workspace path -->

Duong's directive (verbatim): *"store only session state, no config state or
version, only config id which will tell us which config id we're using in the
other db"*. This plan introduces a `configId` FK on session docs, removes the
three leaked fields, updates two stale readers (factoryVersion read in main,
brand read in list_recent_sessions), wipes the 96 existing staging docs via a
short Python admin-SDK script, and lands xfail tests first per Rule 12.

Scope is deliberately narrow. S2 persistence wiring (demo-config-mgmt is
in-memory-only at runtime today) is NOT part of this fix; flagged as open
question. No backfill — wipe-and-restart only, since this is staging.

## Anchors

All anchors live in the mmp work workspace at
`~/Documents/Work/mmp/workspace/company-os/` <!-- orianna: ok -- work workspace path, not in strawberry-agents -->:

- `mmp/workspace/tools/demo-studio-v3/session.py` <!-- orianna: ok -- work workspace path --> — `create_session` (L38-52) is the leak
  writer; `list_recent_sessions` (L118) is a stale reader.
- `mmp/workspace/tools/demo-studio-v3/main.py` <!-- orianna: ok -- work workspace path --> — imports `create_session` at L46;
  `trigger_build` reads `factoryVersion` at L2172; `dashboard_sessions`
  (L3047-3097) already uses `config_mgmt_client.fetch_config` — the pattern
  to mirror in `list_recent_sessions`.
- `mmp/workspace/tools/demo-studio-v3/session_store.py` <!-- orianna: ok -- work workspace path --> — BD-1-compliant; its
  `_UPDATE_ALLOWLIST` must accept `configId`.
- `mmp/workspace/tools/demo-studio-v3/tests/conftest.py` <!-- orianna: ok -- work workspace path --> — fixture at L160 writes
  `configVersion` / `factoryVersion` into session docs; must be stripped.
- `mmp/workspace/tools/demo-studio-v3/config_mgmt_client.py` <!-- orianna: ok -- work workspace path --> — `fetch_config(session_id)`
  is the S2 call used by `dashboard_sessions`.

## Target schema

Session doc fields after the fix:

```
sessionId, status, phase, managedSessionId, factoryRunId, projectId,
outputUrls, qcResult, slackUserId, slackChannel, slackThreadTs,
archivedAt, createdAt, updatedAt, cancelReason, verificationStatus,
verificationReport, lastBuildAt,
configId                    <-- NEW FK, value = session_id (S2 legacy key pattern)
```

Removed: `config`, `configVersion`, `factoryVersion`.

## Branch and workspace

- Workspace: `~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/` <!-- orianna: ok -- work workspace path -->.
- Branch: continue on `feat/demo-studio-v3` <!-- orianna: ok -- git branch name, not a filesystem path --> (same branch as
  Loops 2a / 2b / 2c).
- Use `scripts/safe-checkout.sh` for any new worktree if needed.

## Tasks

All tasks operate on files inside the mmp work workspace
(`~/Documents/Work/mmp/workspace/company-os/` <!-- orianna: ok -- work workspace path -->). Each task lists
kind, estimate_minutes, files, detail, and definition of done.

### T1 — xfail tests for the new schema

- kind: test
- estimate_minutes: 30
- files: `mmp/workspace/tools/demo-studio-v3/tests/test_session_store_no_config_write.py` <!-- orianna: ok -- work workspace path, extend if present -->
  (extend if present, create if not); `mmp/workspace/tools/demo-studio-v3/tests/test_session_create_schema.py` <!-- orianna: ok -- work workspace path, prospective new test file -->
  (new).
- detail: Add xfail-marked tests asserting the following, each with an xfail
  reason string that cites this plan filename.
  1. `create_session(...)` writes a doc whose keys are a subset of the target
     schema plus `configId` and contain NO `config`, `configVersion`, or
     `factoryVersion` keys.
  2. `configId == session_id` on the written doc.
  3. `list_recent_sessions` returns rows whose `brand` field came from a
     mocked `config_mgmt_client.fetch_config` call, not from any session-doc
     `config` field.
  4. `trigger_build` resolves factory version to `2` without reading
     `factoryVersion` from the session dict.
- DoD: tests committed as xfail on branch `feat/demo-studio-v3` <!-- orianna: ok -- git branch name, not a path -->, CI green,
  plan reference present in xfail reason strings.

### T2 — Strip leaked fields from `create_session`

- kind: code
- estimate_minutes: 20
- files: `mmp/workspace/tools/demo-studio-v3/session.py` <!-- orianna: ok -- work workspace path -->.
- detail: In `create_session` (L38-52) remove the three leaked keys and add
  `"configId": session_id`. Drop the `initial_context` parameter's
  pass-through into a `config` field — if the in-process caller still needs
  it, keep it as a return-value-only dict, never persisted. Also review the
  `/session` Slack-relay caller (main.py L1732) to confirm `initialContext`
  is no longer persisted to the session doc.
- DoD: T1 assertions 1 and 2 flip from xfail to pass.

### T3 — Update stale reader in `trigger_build`

- kind: code
- estimate_minutes: 10
- files: `mmp/workspace/tools/demo-studio-v3/main.py` <!-- orianna: ok -- work workspace path -->.
- detail: At L2172 replace `version = session.get("factoryVersion", 1)` with
  a hard-coded `version = 2`. Add an inline comment citing this plan and
  noting factory v2 is the only supported version per investigation `b3729b0`.
- DoD: T1 assertion 4 flips from xfail to pass.

### T4 — Update stale reader in `list_recent_sessions`

- kind: code
- estimate_minutes: 40
- files: `mmp/workspace/tools/demo-studio-v3/session.py` <!-- orianna: ok -- work workspace path -->.
- detail: At L118, replace direct `d.get("config")` brand / market /
  insuranceLine reads with per-row `config_mgmt_client.fetch_config(session_id)`
  calls. Mirror the parallel-fetch pattern already present in
  `main.py::dashboard_sessions` (L3047-3097); do not add a naive serial loop.
  Handle S2 404 / missing config gracefully (row still renders with blank
  brand). Pull the fetch helper into a shared location if it helps, but do
  not refactor beyond what this single reader needs.
- DoD: T1 assertion 3 flips from xfail to pass; dashboard listing still
  renders with brand labels populated.

### T5 — Allowlist `configId` in session_store <!-- orianna: ok -- module name reference -->

- kind: code
- estimate_minutes: 10
- files: `mmp/workspace/tools/demo-studio-v3/session_store.py` <!-- orianna: ok -- work workspace path -->.
- detail: Add `"configId"` to `_UPDATE_ALLOWLIST` so future updates
  (e.g. rotating to an independent UUID config ID) won't be rejected by BD-1.
- DoD: allowlist-path test passes.

### T6 — Strip leaked fields from test fixtures

- kind: test
- estimate_minutes: 15
- files: `mmp/workspace/tools/demo-studio-v3/tests/conftest.py` <!-- orianna: ok -- work workspace path -->.
- detail: At L160, remove `configVersion: 1` and `factoryVersion: 2` from the
  session fixture. Add `configId: <fixture_session_id>`. Grep the rest of
  `mmp/workspace/tools/demo-studio-v3/tests/` <!-- orianna: ok -- work workspace path --> for any direct field assertions on the three
  removed fields and update them.
- DoD: full `pytest tools/demo-studio-v3/tests/` <!-- orianna: ok -- work workspace path --> passes locally; no grep
  hits for `configVersion` / `factoryVersion` in test assertions.

### T7 — Wipe staging session docs

- kind: ops
- estimate_minutes: 15
- files: `mmp/workspace/tools/demo-studio-v3/scripts/wipe_staging_sessions.py` <!-- orianna: ok -- prospective new script in work workspace --> (new).
- detail: One-shot Python admin-SDK script that streams the
  `demo-studio-sessions` collection in the `demo-studio-staging` DB and
  deletes every doc in batches of 500. Log the count deleted. Idempotent.
  Do NOT wipe `demo-studio-used-tokens` (see Open Question 3). Running the
  script is gated behind an explicit `--confirm` flag; no auto-run in CI.
  **Execution requires Duong's explicit go-ahead** — destructive, touches a
  shared DB. Script lands in the PR but is not executed by an agent.
- DoD: script merged; dry-run against staging succeeds (prints planned
  deletion count without actually deleting); execution deferred to human.

### T8 — Manual post-deploy smoke

- kind: qa
- estimate_minutes: 15
- files: none — execution checklist lives in the PR body.
- detail: After T7 runs and a fresh build is deployed to staging, verify in
  order: first, create a new session via `POST /session/new`; next, inspect
  the Firestore doc and confirm it contains `configId` and none of the three
  leaked fields; finally, open the dashboard and confirm the listing renders
  brand / market populated (proving T4's S2-fetch path works).
- DoD: smoke checklist passes; screenshots in PR body.

## Test plan

Per Rule 12, T1 lands first as xfail, on the same branch, before any
implementation commit. Tests protect:

- **No-config-leak invariant** — new session docs never carry `config`,
  `configVersion`, or `factoryVersion`. (T1 assertion 1.)
- **configId FK invariant** — every new session doc has `configId`, and its
  value equals `sessionId` until S2 gets independent UUID IDs. (T1 assertion 2.)
- **Dashboard brand-source invariant** — `list_recent_sessions` resolves
  brand via S2 `fetch_config`, not by reading a session-doc `config` blob.
  (T1 assertion 3.)
- **Factory-version invariant** — `trigger_build` uses factory v2
  unconditionally and does not read `factoryVersion` from the session dict.
  (T1 assertion 4.)

The pre-push hook's TDD gate (Rule 12) enforces the xfail-first ordering.

## Open questions

1. **S2 persistence.** `demo-config-mgmt` is in-memory-only at runtime today
   (per investigation section 1). After this fix lands, every session doc's
   `configId` is an FK into the S2 store, which means on pod restart those
   FKs become dangling pointers. Do we wire S2 to persist to the existing
   `demo-config-mgmt` Firestore DB as an immediate follow-up, or accept the
   dangling-pointer window for this fix? Plan does NOT wire S2; track it as
   a separate plan.
2. **`configId` identity shape.** Keep `configId == sessionId` (current S2
   doc key pattern), or refactor S2 to independent UUID doc IDs so one
   session can reference a different config version? Deferred — T5 adds the
   allowlist entry so the field can be rotated later without schema change.
3. **`demo-studio-used-tokens` wipe.** Leaving tokens intact keeps any
   already-issued one-time URLs valid but orphaned (session doc gone).
   Wipe-with-sessions keeps state consistent but opens a token-replay window
   for in-flight links. Default per this plan: leave tokens alone; revisit
   if orphaned-token errors surface.

## Out of scope

- Wiring S2 to persist to `demo-config-mgmt` Firestore (Open Question 1).
- Any backfill / migration of existing 96 docs — wipe only.
- Migrating main.py's import from the `session` module to `session_store` — <!-- orianna: ok -- module name references, not filesystem paths -->
  short-term fix is in-place on the `session` module. <!-- orianna: ok -- module name reference -->
- Route migration for `/session/{sid}/*` auth — that is Loop 2c.

## References

- Investigation: `assessments/work/2026-04-22-firestore-config-mgmt-leak-investigation.md` at commit `b3729b0`.
- BD-1 compliance module: `mmp/workspace/tools/demo-studio-v3/session_store.py` <!-- orianna: ok -- work workspace path -->.
- S2 client: `mmp/workspace/tools/demo-studio-v3/config_mgmt_client.py` <!-- orianna: ok -- work workspace path -->.
- Sibling branch context: `plans/proposed/work/2026-04-22-firebase-auth-loop2c-route-migration.md`.
