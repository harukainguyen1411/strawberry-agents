---
status: approved
orianna_gate_version: 2
complexity: normal
concern: work
owner: Aphelios
created: 2026-04-21
parent_plan: 2026-04-20-s1-s2-service-boundary.md
tags:
  - demo-studio
  - service-1
  - service-2
  - architecture
  - boundary
  - work
  - tasks
tests_required: true
---

# Task breakdown — S1/S2 Service Boundary (BD)

Source ADR: `plans/approved/work/2026-04-20-s1-s2-service-boundary.md` (§1–§12, all seven OQs RESOLVED, Orianna-signed 2026-04-21).

Branch: `feat/demo-studio-v3` (company-os worktree at `~/Documents/Work/mmp/workspace/company-os-demo-studio-v3`). Same branch as SE / MAL / MAD — four ADRs share one PR branch per §11 / §12 handoff notes.

Task-ID scheme: `BD.<phase>.<n>`. Phases track the ADR's deletion/refactor structure (§3 + §5) and the grep-gate extension (§2 Rule 4), not file-by-file. Every impl task is preceded by an xfail TEST commit on the same branch per Rule 12.

AI-minute estimates are wall-clock Sonnet-builder time per commit (test and impl commits counted separately). Estimates exclude Aphelios breakdown + Senna review time.

---

## Cross-ADR dependency map (load-bearing — read first)

BD's execution is tightly interlocked with three sibling ADRs living on the same branch. As of 2026-04-21: BD is **approved + signed**; MAD is **approved + decomposed**; MAL and SE are **approved, decomposing now** (Kayn in parallel). Hard ordering from ADR §7 stands.

| BD phase | SE task it touches | Ordering rule |
| --- | --- | --- |
| BD.A (pre-delete audit) | — | Must precede BD.B.* (needs live line-number rebaseline vs. HEAD of branch). |
| BD.B.1 (delete `SAMPLE_CONFIG` + `main.py` session-creation config plumbing) | **must land BEFORE SE.B.2** | SE.B.2 migrates the same call sites; landing BD after forces rework. |
| BD.B.2 (delete embedded `config` / `configVersion` writes from `session.create_session`) | **must land INSIDE SE.A.4** | SE.A.4 is where `session_store.create_session` is implemented — BD shapes its signature (no `brand/market/languages/shortcode/configVersion`). |
| BD.B.3 (delete `map_config_to_factory_params` + `_build_content_from_config` + `validate_v2.py`) | **must land BEFORE SE.B.4** | SE.B.4 migrates `factory_bridge*.py`; BD deletions land first, SE.B.4 migrates the shrunken surface. |
| BD.B.4 (delete `factory_bridge_v2.prepare_demo_dict` + factory-path config-fetches) | **must land BEFORE SE.B.4** | Same reasoning. |
| BD.C.* (refactor: S2-fetch on render/history/status paths) | **parallelisable with SE.B.2** | Distinct call sites; no collision as long as BD.B.1 lands first. |
| BD.D (delete `config_mgmt_client.patch_config` + `sample-config.json`) | independent of SE | Any wave. |
| BD.E (grep-gate extension — two new patterns) | **must land INSIDE SE.E.2** | SE.E.2 is the grep-gate CI step; BD.E contributes two additional patterns + allowlist entries. Coordinate with Camille (SE.E owner). |
| BD.F (thin `POST /build {sessionId}` pass-through) | SE.B.4 shares `trigger_factory` scaffold | **Parallelisable with SE.B.4** after BD.B.3/B.4 land. Confirm S3 self-fetch live (per ADR §8.2) before merging. |
| BD.G (agent-init refactor: identity-only payload to managed agent) | SE.F.1 | **Parallelisable with SE.F.1.** Exact shape is Kayn's to refine in SE.F.1 follow-up (ADR §5.1). BD.G ships the minimal "strip full config, send identity four" change. |

**Cross-ADR task handoffs recorded:**
- **BD.E.2 ↔ SE.E.2** — the two grep-gate regex patterns from ADR §2 Rule 4 (`session\[?["\']config["\']\]?\s*=` and literal `insuranceLine`) must be committed to the SE.E.2 gate config, NOT a separate BD-only gate. Camille owns the gate file; BD.E.2 is an amendment PR on top of SE.E.2.
- **BD.E.3 ↔ MAD.E.1** — the MAD dashboard list handler is on BD §3.14 allowlist (an allowed caller of `config_mgmt_client`). MAD.E.1 (Kayn's breakdown) verifies the allowlist entry exists. BD.E.3 adds the entry to the gate config; MAD.E.1 confirms.
- **BD.B.2 ↔ SE.A.4** — BD.B.2 is a commit **inside** the SE.A.4 branch of work (not a separate PR). The SE.A.4 task body changes shape because of BD: `session_store.create_session(...)` has NO `brand`, NO `market`, NO `languages`, NO `shortcode`, NO `configVersion`, NO `config` params. Kayn must amend SE.A.4 in the SE task file (if already decomposed) or see this constraint when decomposing.

---

## Phase summary & estimates

| Phase | Scope | Tasks | AI-min |
| --- | --- | --- | --- |
| BD.0 | Preflight: line-number rebaseline + worktree check | 2 | 20 |
| BD.A | Deletion manifest + coverage map (audit errand) | 2 | 30 |
| BD.B | Delete-from-S1 (session-creation + factory-translation families) | 8 (4 xfail + 4 impl) | 240 |
| BD.C | Refactor-in-S1 (render/status/history S2-fetch call sites) | 6 (3 xfail + 3 impl) | 180 |
| BD.D | Delete config-client leftovers (`patch_config` + `sample-config.json`) | 2 (1 xfail + 1 impl) | 35 |
| BD.E | Grep-gate extension (two patterns + allowlist) | 4 (1 xfail + 2 impl + 1 errand) | 90 |
| BD.F | Factory path: thin `POST /build {sessionId}` pass-through | 2 (1 xfail + 1 impl) | 55 |
| BD.G | Agent-init refactor: identity-only payload | 2 (1 xfail + 1 impl) | 50 |
| BD.H | Deletion sentinel (orphan-path check: every row in §3.14 gone) | 1 (test only) | 20 |
| **TOTAL** | | **29** | **720** |

Rough wave diagram (serial `→`, parallel within wave `∥`):

```
Wave 0: BD.0.1 → BD.0.2
Wave 1: BD.A.1 → BD.A.2
Wave 2: BD.B.1 (xfail) → BD.B.2 (impl) ∥ BD.B.3 (xfail) → BD.B.4 (impl)   [main.py session-create]
        BD.B.5 (xfail) → BD.B.6 (impl) ∥ BD.B.7 (xfail) → BD.B.8 (impl)   [factory-translation delete]
Wave 3: BD.C.1 → BD.C.2 ∥ BD.C.3 → BD.C.4 ∥ BD.C.5 → BD.C.6               [refactor render/status/history]
Wave 4: BD.D.1 → BD.D.2
Wave 5: BD.E.1 → BD.E.2 ∥ BD.E.3 → BD.E.4
Wave 6: BD.F.1 → BD.F.2
Wave 7: BD.G.1 → BD.G.2
Wave 8: BD.H.1
```

Waves 2 and 3 can overlap if the session-create and factory-translation call sites are disjoint (they are — see §3.1/§3.2 vs. §3.3/§3.4). Waves 5/6/7 can interleave with Wave 3 if capacity allows; dispatch at Sona's discretion.

---

## Phase BD.0 — Preflight

### BD.0.1 — Line-number rebaseline against branch HEAD (ERRAND)
- **What:** ADR §3 line numbers are pinned to `feat/demo-studio-v3@d327581`. On start, rebaseline against current branch HEAD and append a "BD.0.1 result" table to this file mapping each §3 row to its current line number. Flag any row whose shape changed (e.g. an insert pushed the `config` write to a new wrapper function).
- **Deliverable:** table with columns `ADR §3 row | file | ADR-cited line | current line | drift? (y/n) | notes`.
- **Acceptance:** Aphelios/Sona can read the table and confirm zero-drift or queue an ADR line-number patch.
- **Blockers:** none.
- **AI-min:** 15.

### BD.0.2 — Worktree hygiene (ERRAND)
- **What:** confirm `~/Documents/Work/mmp/workspace/company-os-demo-studio-v3` is on `feat/demo-studio-v3` and clean. If absent, `git worktree add` it (raw — company-os has no `safe-checkout.sh`).
- **Acceptance:** `git -C ~/Documents/Work/mmp/workspace/company-os-demo-studio-v3 status` clean on `feat/demo-studio-v3`.
- **Blockers:** none.
- **AI-min:** 5.

---

## Phase BD.A — Deletion manifest + coverage map (audit)

### BD.A.1 — Build deletion manifest from §3.14 (ERRAND)
- **What:** produce `tools/demo-studio-v3/tests/fixtures/bd_deletion_manifest.json` listing every (file, symbol, line range) in ADR §3.14's 17-row Delete list. One object per entry: `{file, symbol, startLine, endLine, adrRef, replacement}`. Used by BD.H.1 as the sentinel-assertion input, and by Senna as the PR-review checklist.
- **Acceptance:** 17 entries; each line range validated against BD.0.1 rebaseline; each `adrRef` points to a §3.x row.
- **Blockers:** BD.0.1.
- **AI-min:** 20.

### BD.A.2 — Map current test coverage to §3.14 rows (ERRAND)
- **What:** grep `tools/demo-studio-v3/tests/` for references to every symbol on the delete list. Produce `bd_test_coverage_map.md` noting which delete-rows currently have tests, which tests must be deleted (those asserting the behaviour we're removing), which tests must be rewritten (those asserting the S2-fetch behaviour we're adding). Flag `tests/test_no_local_validation.py:41-47` as pre-existing xfail that will flip green post-BD (see ADR §3.8, §9).
- **Acceptance:** map covers all 17 delete rows + all 5 refactor rows + all 3 keep rows.
- **Blockers:** BD.A.1.
- **AI-min:** 10.

---

## Phase BD.B — Delete-from-S1

Covers the 11 delete-rows in §3.14 that are session-creation + factory-translation surgery. The remaining delete-rows land in BD.D (client leftover) or are covered by the refactor tasks (BD.C) after the delete portion lands.

### BD.B.1 — xfail: `main.py` session-creation config plumbing gone (TEST)
- **What:** add `tests/test_main_session_create_no_config.py`. Tests:
  1. `main.SAMPLE_CONFIG` attribute does not exist (module-level deletion).
  2. `POST /session/new` (UI variant) with a body that includes `insuranceLine` rejects the field (422) OR silently drops it — matches chosen behaviour in §3.2 row 1192 / §5.1 (rejects, since `insuranceLine` is not in any schema S1 owns post-BD).
  3. `POST /session/new` flow: the Firestore write payload contains NO `config`, NO `configVersion`, NO `brand`/`market`/`languages`/`shortcode` keys (identity fields are agent-input only).
  4. Internal `POST /session` variant: same assertions.
  5. `main.create_new_session_ui` no longer calls `create_session(initial_context=...)` — either the kwarg is gone from the call, or the function signature itself has dropped it (paired w/ SE.A.4).
- **Acceptance:** all xfail strict. Test file references `plans/approved/work/2026-04-20-s1-s2-service-boundary.md §3.2`.
- **Commit:** `chore: add xfail tests for main.py session-create config-plumbing deletion (BD.B.1)`.
- **AI-min:** 30.

### BD.B.2 — impl: delete `SAMPLE_CONFIG` + session-create config plumbing in `main.py` (BUILDER)
- **What:** execute ADR §3.2 rows 53 / 1190 / 1192 / 1196–1201 / 1250–1254 deletions. Concretely:
  - Remove `SAMPLE_CONFIG: dict = {}` module-level (line 53).
  - In `create_new_session_ui` and `create_new_session` (internal): remove `initial_context = json.loads(json.dumps(SAMPLE_CONFIG))` deep-copy; remove `initial_context["insuranceLine"] = ...`; remove the `initial_context=initial_context` kwarg on `create_session(...)`; the body is reduced to the lifecycle-only fields.
  - Session create call becomes `session_store.create_session(session_id=..., slack_user_id=..., slack_thread_ts=..., factory_version=...)` — no config, no identity fields. (If SE.A.4 not yet landed, inline-adapt to current `create_session` signature and note in PR description that BD.B.2 absorbs into SE.A.4 on merge.)
  - Body-model for `POST /session/new`: drop `insuranceLine` field from the Pydantic body class. Keep `brand`, `market`, `languages`, `shortcode` on the request body (they're agent-input, consumed by the `managed_agent.boot(...)` call — BD.G handles that refactor). Add field-level assertion to reject `insuranceLine`.
- **Acceptance:** BD.B.1 tests pass. Pre-existing green tests that depend on `SAMPLE_CONFIG` being readable fail — expected, they're on BD.A.2's "must delete" list.
- **Depends on:** BD.B.1. Coordinates with SE.A.4.
- **Commit:** `refactor(demo-studio-v3): delete SAMPLE_CONFIG + session-create config plumbing (BD.B.2)`.
- **AI-min:** 40.

### BD.B.3 — xfail: `session.py::create_session` no config/configVersion write (TEST)
- **What:** `tests/test_session_store_no_config_write.py`. Tests:
  1. `create_session(...)` (or `session_store.create_session` if SE.A.4 landed) writes a Firestore document whose keys are the lifecycle set only (no `config`, no `configVersion`, no `brand`/`market`/`languages`/`shortcode`).
  2. `_UPDATABLE_FIELDS` allowlist (§3.1 line 133) is unchanged, but the test asserts `"config"`, `"configVersion"`, `"brand"`, `"market"`, `"languages"`, `"shortcode"` are NOT in the allowlist — regression guard against future re-adds.
  3. `list_recent_sessions(...)` response rows contain lifecycle-only keys: `{sessionId, status, phase, createdAt, updatedAt, managedSessionId?, factoryRunId?, projectId?}`. No `brand` / `market` / `insuranceLine` keys (§3.1 rows 118–128).
- **Acceptance:** xfail strict.
- **Commit:** `chore: add xfail tests for session.py config/identity-field exclusion (BD.B.3)`.
- **AI-min:** 25.

### BD.B.4 — impl: delete `config`/`configVersion` writes + identity-field extraction in `session.py` (BUILDER)
- **What:** execute ADR §3.1 rows 42 / 43 / 118–128.
  - Remove `"config": initial_context or {}` from `create_session` Firestore write.
  - Remove `"configVersion": 1` write.
  - Rewrite `list_recent_sessions(...)` to return lifecycle-only `SessionSummary` rows (no `brand`/`market`/`insuranceLine` reads).
  - `_UPDATABLE_FIELDS` unchanged.
- **Acceptance:** BD.B.3 tests pass. This task's impl lands INSIDE the SE.A.4 commit if SE.A.4 hasn't landed yet (co-author with Kayn); otherwise as a follow-up commit on top of SE.A.4.
- **Depends on:** BD.B.3. Coordinates with SE.A.4.
- **Commit:** `refactor(demo-studio-v3): delete config/configVersion writes + identity-field extraction in session.py (BD.B.4)`.
- **AI-min:** 35.

### BD.B.5 — xfail: factory_bridge translation functions gone (TEST)
- **What:** `tests/test_factory_bridge_no_translation.py`. Tests:
  1. Importing `map_config_to_factory_params` from `tools.demo_studio_v3.factory_bridge` raises `ImportError` (symbol deleted).
  2. Importing `_build_content_from_config` from same raises `ImportError`.
  3. Importing `prepare_demo_dict` from `tools.demo_studio_v3.factory_bridge_v2` raises `ImportError`.
  4. Module `tools.demo_studio_v3.factory_v2.validate_v2` does not exist (ModuleNotFoundError).
  5. `trigger_factory(session_id)` function still exists but reduces to: read session, POST to S3 with `{sessionId}` only, persist `factoryRunId`. Mocks `factory_client.start_build` and asserts it's called with `{"sessionId": "sess_..."}` exactly (no `configVersion`, no translated payload). (Impl of the thin pass-through is BD.F; this xfail scopes only the deletion shape.)
  6. `trigger_factory_v2(session_id)` same shape.
- **Acceptance:** xfail strict.
- **Commit:** `chore: add xfail tests for factory-translation deletion (BD.B.5)`.
- **AI-min:** 30.

### BD.B.6 — impl: delete factory-translation families (BUILDER)
- **What:** execute ADR §3.3 rows 33–129 / 142–190 / 209 / 210–211 / 250/253 and §3.4 rows 35–63 / 82 / 97/109–115 / 118 / 140–143 and §3.5 entire file.
  - Delete `map_config_to_factory_params` from `factory_bridge.py`.
  - Delete `_build_content_from_config` from `factory_bridge.py`.
  - Delete `prepare_demo_dict` from `factory_bridge_v2.py`.
  - Delete `factory_v2/validate_v2.py` (entire file).
  - Inside `trigger_factory` and `trigger_factory_v2`: remove `config = session.get("config", {})`, remove translation calls, remove `logos/bg_color` reads. Leave the function bodies as scaffold (read session → call factory_client → persist factoryRunId — actual thin pass-through body is BD.F.2 once the factory_client method exists).
  - Remove any imports that become unused.
- **Acceptance:** BD.B.5 items 1–4 green. Items 5–6 still xfail (body filled in BD.F.2). `tests/test_no_local_validation.py` moves from xfail → pass (pre-existing Jayce-unfinished test, per ADR §3.8).
- **Depends on:** BD.B.5.
- **Commit:** `refactor(demo-studio-v3): delete factory-param translation + validate_v2 (BD.B.6)`.
- **AI-min:** 45.

### BD.B.7 — xfail: preview route + preview.py gone from S1 (TEST)
- **What:** `tests/test_preview_deleted_from_s1.py`. Tests:
  1. `GET /session/{id}/preview` returns 404 (route unregistered) — NOT 200 with a rendered preview.
  2. `tools.demo_studio_v3.preview` module does not exist (ModuleNotFoundError) — file deleted.
  3. `main.render_preview` symbol not imported.
- **Acceptance:** xfail strict. Per ADR §8.2, traffic redirect/410 handling for the deleted route is S5's concern and out of scope here.
- **Commit:** `chore: add xfail tests for S1 preview deletion (BD.B.7)`.
- **AI-min:** 15.

### BD.B.8 — impl: delete `/preview` route + `preview.py` from S1 (BUILDER)
- **What:** execute ADR §3.2 row 1439–1445 (route) + §3.6 (file).
  - Remove route registration for `GET /session/{id}/preview` in `main.py`.
  - Delete `tools/demo-studio-v3/preview.py` entirely.
  - Remove any imports of `render_preview` / `preview` from `main.py`.
- **Acceptance:** BD.B.7 tests pass.
- **Depends on:** BD.B.7.
- **Commit:** `refactor(demo-studio-v3): delete /preview route + preview.py from S1 (BD.B.8)`.
- **AI-min:** 20.

---

## Phase BD.C — Refactor-in-S1 (render/status/history S2-fetch call sites)

Covers the 5 refactor-rows in §3.14 that stay on S1 but rewrite to fetch from S2.

### BD.C.1 — xfail: `session_page` title S2-fetch + cold-session fallback (TEST)
- **What:** `tests/test_session_page_title_s2_fetch.py`. Tests:
  1. `GET /session/{id}` renders page; under the hood, `config_mgmt_client.fetch_config(session_id)` is called once; `<title>` contains the returned `config.brand`.
  2. On S2 404 (cold session, no first `set_config` yet): `<title>` contains `"New Session"` fallback; no error log emitted.
  3. On S2 5xx: `<title>` contains `"New Session"` fallback; error log emitted at WARN with key `s2_render_fetch_failed`.
- **Acceptance:** xfail strict.
- **Commit:** `chore: add xfail tests for session_page S2-fetch title (BD.C.1)`.
- **AI-min:** 20.

### BD.C.2 — impl: session_page title via S2 fetch (BUILDER)
- **What:** execute ADR §3.2 row 1349 refactor. Replace `session.get("config", {}).get("brand", "New Session")` with `await config_mgmt_client.fetch_config(session_id)` and pull `config.brand`. Wrap in try/except for `NotFoundError` (cold) and generic exception (5xx) — both fall back to `"New Session"`.
- **Acceptance:** BD.C.1 tests pass.
- **Depends on:** BD.C.1.
- **Commit:** `refactor(demo-studio-v3): session_page title via S2 fetch (BD.C.2)`.
- **AI-min:** 25.

### BD.C.3 — xfail: `chat` lazy-create title via S2; insuranceLine gone (TEST)
- **What:** `tests/test_chat_lazy_create_title_s2.py`. Tests:
  1. On lazy managed-session create (§3.2 row 1395–1397), `config_mgmt_client.fetch_config(session_id)` is called; agent title derived from `config.brand`, `config.market`; NO `insuranceLine` in the derivation (symbol not referenced anywhere in S1).
  2. S2 404 during lazy-create: title derives with `brand="New Session"` fallback; lazy-create proceeds.
  3. S2 5xx: same fallback; WARN log.
- **Acceptance:** xfail strict.
- **Commit:** `chore: add xfail tests for chat lazy-create S2-fetch title (BD.C.3)`.
- **AI-min:** 20.

### BD.C.4 — impl: chat lazy-create title via S2 (BUILDER)
- **What:** execute ADR §3.2 row 1395–1397 refactor. Replace three-key `session.get("config", {}).get(...)` reads with an S2 fetch; drop the `insuranceLine` key from the agent-title derivation entirely (per ADR: `insuranceLine` is not in S2 schema). Error handling same shape as BD.C.2.
- **Acceptance:** BD.C.3 tests pass.
- **Depends on:** BD.C.3.
- **Commit:** `refactor(demo-studio-v3): chat lazy-create title via S2 (BD.C.4)`.
- **AI-min:** 25.

### BD.C.5 — xfail: `session_status` response shape shrinks + `session_history` via S2 (TEST)
- **What:** `tests/test_session_status_and_history_shapes.py`. Tests:
  1. `GET /session/{id}/status` response has keys subset of `{status, phase, createdAt, updatedAt, managedSessionId, factoryRunId, projectId, outputUrls, qcResult}`. No `logos`, no `configVersion`, no `brand`/`market` (per OQ-BD-2 + OQ-BD-3 resolutions).
  2. `GET /session/{id}/history` (if the endpoint exists — see ADR §3.2 row 1987–2001): summary row's `brand` field comes from a `config_mgmt_client.fetch_config(...)` call, not from `session.config.brand`.
  3. History on S2 404: summary shows `brand: null` with a UI-safe fallback; no error.
- **Acceptance:** xfail strict.
- **Commit:** `chore: add xfail tests for status/history shape changes (BD.C.5)`.
- **AI-min:** 25.

### BD.C.6 — impl: `session_status` shrink + `session_history` S2 fetch (BUILDER)
- **What:** execute ADR §3.2 rows 1461–1472 and 1987–2001.
  - `session_status`: drop `logos` field (§3.2 row 1461–1472, per OQ-BD-2). Drop `configVersion` from response (not on session doc post-BD.B.4). Drop `brand`/`market` if present. Response is strictly lifecycle.
  - `session_history`: rewrite the `cfg = session.get("config") or {}` path to `cfg = await config_mgmt_client.fetch_config(session_id)` (or skip on 404). For version history (optional future feature), note that `GET /v1/config/{sessionId}/versions` is the S2 call; leave a `# TODO(SE.F)` marker — not in BD scope.
- **Acceptance:** BD.C.5 tests pass.
- **Depends on:** BD.C.5.
- **Commit:** `refactor(demo-studio-v3): session_status shrink + session_history via S2 (BD.C.6)`.
- **AI-min:** 30.

---

## Phase BD.D — Delete config-client leftovers

### BD.D.1 — xfail: `patch_config` + `sample-config.json` gone (TEST)
- **What:** `tests/test_config_client_and_sample_deleted.py`. Tests:
  1. Importing `patch_config` from `tools.demo_studio_v3.config_mgmt_client` raises `ImportError`.
  2. `tools/demo-studio-v3/sample-config.json` does not exist (`os.path.exists` false).
  3. `config_mgmt_client.fetch_config` and `fetch_schema` still import and function (sanity guard — we're not deleting the keepers).
- **Acceptance:** xfail strict on 1–2; 3 passes.
- **Commit:** `chore: add xfail tests for patch_config + sample-config.json deletion (BD.D.1)`.
- **AI-min:** 10.

### BD.D.2 — impl: delete `patch_config` + `sample-config.json` (BUILDER)
- **What:** execute ADR §3.7 row 94–108 + §3.8.
  - Remove `patch_config` function from `config_mgmt_client.py`.
  - `git rm tools/demo-studio-v3/sample-config.json`.
  - Remove any imports/references of `patch_config` (runtime had none per ADR; test references fold into BD.A.2's "must delete" list).
- **Acceptance:** BD.D.1 tests pass.
- **Depends on:** BD.D.1.
- **Commit:** `refactor(demo-studio-v3): delete patch_config + sample-config.json (BD.D.2)`.
- **AI-min:** 25.

---

## Phase BD.E — Grep-gate extension

Extends SE.E.2's grep gate with the two patterns from ADR §2 Rule 4, and seeds the allowlist for known valid callers.

### BD.E.1 — xfail: grep gate catches new patterns (TEST)
- **What:** `tests/test_config_boundary_grep_gate.py`. Tests:
  1. Create a synthetic file `tests/fixtures/bd_gate_violator.py` containing `session["config"] = {"foo": 1}` and run `scripts/grep-gate.sh` (or whatever entry point SE.E.1 produced). Gate exits non-zero.
  2. Synthetic file containing literal `"insuranceLine"` anywhere in source runs → gate exits non-zero.
  3. A file carrying `# azir: config-boundary` on the violating line → gate exits zero (whitelist comment works, per ADR §2 Rule 4 last paragraph).
  4. `main.py` (dashboard handler imports `config_mgmt_client`) does NOT trigger the gate (already on BD §3.14 allowlist).
- **Acceptance:** xfail strict until BD.E.2 lands.
- **Commit:** `chore: add xfail tests for config-boundary grep-gate patterns (BD.E.1)`.
- **AI-min:** 20.

### BD.E.2 — impl: add two patterns to SE.E.2 gate config (BUILDER, cross-ADR)
- **What:** amend the SE.E.2 gate config (file lives in SE's scope; exact path TBD by Camille in SE.E.1/E.2). Add two regexes per ADR §2 Rule 4:
  - `session\[?["\']config["\']\]?\s*=` (assignment of `session["config"]` or `session.config`).
  - Literal string `insuranceLine`.
  - Scope: files under `tools/demo-studio-v3/` excluding `tests/` and any explicit migration script.
  - Whitelist comment: `# azir: config-boundary` (mirrors SE.E convention of `# azir: <name>` suppressor).
- **Coordination:** if SE.E.2 has landed before BD.E.2 dispatch → amend it in this PR. If SE.E.2 is mid-flight → co-author with Camille (add patterns to her open PR). If SE.E.2 hasn't started → park BD.E.2 until SE.E.1 (gate infra) lands; BD.E.2 then follows as a thin amendment.
- **Acceptance:** BD.E.1 tests 1–3 green. Test 4 separately verified by BD.E.3.
- **Depends on:** BD.E.1; SE.E.1 (gate infra must exist). **Cross-ADR: coordinate with Camille (SE.E owner).**
- **Commit:** `feat(demo-studio-v3): extend grep-gate with config-boundary patterns (BD.E.2)`.
- **AI-min:** 25.

### BD.E.3 — impl: seed grep-gate allowlist for dashboard handler + migration script (BUILDER)
- **What:** add to the SE.E.2 gate allowlist:
  - The dashboard list handler in `main.py` (MAD.B.2's `GET /api/managed-sessions` handler) — on BD §3.14 allowlist as an allowed `config_mgmt_client` caller.
  - Any explicit migration script path (if BD.B.* introduces one — ADR §8.1 recommends option B orphan, so likely no migration script; if B.4/B.6 needs one, it's listed here).
  - The pre-existing SE.A.6/SE.B.4 call sites that read config through `config_mgmt_client` (render/status/history — BD.C.2/C.4/C.6) — on BD §3.14 allowlist as allowed callers (they're the refactor targets, they SHOULD call the client).
- **Acceptance:** BD.E.1 test 4 green. Coordinated with MAD.E.1 (Kayn's MAD task that verifies this same allowlist entry).
- **Depends on:** BD.E.2. **Cross-ADR: MAD.E.1 re-verifies this allowlist post-merge.**
- **Commit:** `feat(demo-studio-v3): seed grep-gate allowlist for config_mgmt_client callers (BD.E.3)`.
- **AI-min:** 20.

### BD.E.4 — ERRAND: grep-gate CI integration confirmation (ERRAND)
- **What:** confirm the extended gate runs on every PR to `feat/demo-studio-v3` via CI (piggy-backs on SE.E.2's CI hook). Run the gate against branch HEAD post-BD.B-H; it must be green. If the gate flags an unexpected site, decide: (a) legitimately violating → fix; (b) legitimate caller missing from allowlist → amend BD.E.3; (c) gate false-positive → refine regex (rare).
- **Acceptance:** gate green on the branch after all BD.B / BD.C / BD.D / BD.F / BD.G impl tasks have merged.
- **Depends on:** BD.E.3 + all BD.B/C/D/F/G impl tasks.
- **AI-min:** 25.

---

## Phase BD.F — Thin `POST /build {sessionId}` pass-through

Finishes the shell that BD.B.6 left behind for `trigger_factory*`.

### BD.F.1 — xfail: trigger_factory* thin pass-through shape (TEST)
- **What:** `tests/test_trigger_factory_thin.py`. Tests:
  1. `trigger_factory(session_id)` flow: (a) `session_store.get_session(session_id)` called once; (b) `session_store.transition_status(..., to="building")` called once; (c) `factory_client.start_build(session_id)` called with ONLY `{"sessionId": "..."}` — no `configVersion`, no `content`, no translated payload; (d) `session_store.update_session(session_id, factoryRunId=...)` called with the S3-returned run id; (e) returns 202/accepted.
  2. `trigger_factory_v2(session_id)` same shape against `factory_client_v2.start_build`.
  3. S3 5xx: `transition_status(to="building")` is rolled back (to="configuring" or whatever the prior status was) before raising — or the rollback posture is explicitly "no rollback, leave `building` for ops to notice". Choose the former if SE.A.6 exposes a rollback path; note the choice in impl PR description.
  4. No `config_mgmt_client.fetch_config` call on the factory path (regression guard against the old pattern creeping back).
- **Acceptance:** xfail strict. This task partially covers BD.B.5 items 5–6 that were left xfail.
- **Commit:** `chore: add xfail tests for trigger_factory thin pass-through (BD.F.1)`.
- **AI-min:** 25.

### BD.F.2 — impl: thin `POST /build {sessionId}` in trigger_factory* (BUILDER)
- **What:** complete the `trigger_factory*` bodies per ADR §5.3 target pseudocode:
  ```
  POST /session/{id}/build (S1)
    └── session_store.get_session(session_id)    # lifecycle-only; no config read
    └── session_store.transition_status(..., to="building")
    └── factory_client.start_build(session_id)   # POST /build {sessionId} to S3
    └── session_store.update_session(factoryRunId=...)
    └── return accepted
  ```
  - `factory_client.start_build(session_id)` is an existing method or needs a small `body={"sessionId": session_id}` tweak — verify against current `factory_client.py`; if it currently sends a translated payload, shrink to `{sessionId}` per OQ-BD-6.
  - Same for `factory_client_v2`.
  - **S3-side pre-flight:** per ADR §8.2, Sona must confirm S3's self-fetch path (S3 reads config from S2 itself) is live on stg/prod before BD.F.2 merges. If not live, hold BD.F.2 behind the same feature flag as MAD (`MANAGED_AGENT_DASHBOARD` is unrelated — this one is fresh: `S1_FACTORY_THIN_PASSTHROUGH=1`), default off in prod.
- **Acceptance:** BD.F.1 tests pass; BD.B.5 items 5–6 flip green.
- **Depends on:** BD.F.1, BD.B.6. **Cross-team: Sona confirms S3 self-fetch live before merge.**
- **Commit:** `feat(demo-studio-v3): trigger_factory thin POST /build {sessionId} (BD.F.2)`.
- **AI-min:** 30.

---

## Phase BD.G — Agent-init refactor (identity-only payload)

Covers the 2 refactor-rows in §3.14 that are `send_message` calls to the managed agent.

### BD.G.1 — xfail: agent-init message shape is identity-only (TEST)
- **What:** `tests/test_agent_init_identity_only.py`. Tests:
  1. `POST /session/new` flow: `send_message` (or whatever the agent-boot primitive is — §3.2 row 1219) is called with a payload containing ONLY `{brand, market, languages, shortcode}` (or whatever subset the body supplied). No `logos`, no `colors`, no `card`, no `params`, no `journey`, no `tokenUi`, no `insuranceLine`, no `persona`, no `ipadDemo`.
  2. Internal `POST /session` flow: same shape (§3.2 row 1284).
  3. If the body omits any of the four identity fields, `send_message` is called with only the supplied subset (no default-fill from a sample config).
  4. The message body is explicitly NOT `json.dumps(initial_context)` against a full config dict.
- **Acceptance:** xfail strict. The exact wire shape of the agent-init message is Kayn's to refine in SE.F.1 (per ADR §5.1) — BD.G.1 asserts only the minimal "strip full config, send identity four" invariant.
- **Commit:** `chore: add xfail tests for agent-init identity-only payload (BD.G.1)`.
- **AI-min:** 20.

### BD.G.2 — impl: agent-init send identity fields only (BUILDER)
- **What:** execute ADR §3.2 rows 1219 and 1284 refactor. In both `create_new_session_ui` and internal `create_new_session`:
  - Replace `send_message(..., f"Initial context: {json.dumps(initial_context)}")` with a minimal payload carrying only `{brand, market, languages, shortcode}` from the request body.
  - Drop the `initial_context` local variable entirely (already dead after BD.B.2).
  - Leave a `# TODO(SE.F.1)` marker noting the wire shape is Kayn's to finalise.
- **Acceptance:** BD.G.1 tests pass.
- **Depends on:** BD.G.1, BD.B.2. **Cross-ADR: SE.F.1 refines the wire shape as a follow-up — BD.G.2 ships the deletion, not the final shape.**
- **Commit:** `refactor(demo-studio-v3): agent-init identity-only payload (BD.G.2)`.
- **AI-min:** 30.

---

## Phase BD.H — Deletion sentinel

Final cross-phase correctness guard. Asserts that every row on §3.14's 17-entry Delete list has actually been deleted at branch HEAD post-all-BD-phases. Catches silent regressions where a symbol was removed from one file but re-added in another.

### BD.H.1 — TEST: deletion-manifest sentinel (TEST)
- **What:** `tests/test_bd_deletion_sentinel.py`. For each entry in `tests/fixtures/bd_deletion_manifest.json` (from BD.A.1):
  - If entry is a symbol: `import`-based assertion that the symbol raises `ImportError` / `AttributeError`.
  - If entry is a file: `os.path.exists` false.
  - If entry is a Firestore key: inspect the create-session write payload (fixture-captured) and assert key absent.
  Aggregate all 17 assertions; any one fail fails the whole test. Print a per-row status report on failure so PR reviewers see which deletions regressed.
- **Acceptance:** test green at branch HEAD after BD.B, BD.C, BD.D, BD.F, BD.G all merged.
- **Depends on:** BD.A.1 (manifest), all BD.B/C/D/F/G impl tasks.
- **Commit:** `test(demo-studio-v3): BD deletion sentinel (BD.H.1)`.
- **AI-min:** 20.

---

## xfail TEST ↔ impl BUILDER pairing

Per Rule 12 every impl task is preceded on the same branch by an xfail test commit.

| xfail TEST | impl BUILDER | Phase |
| --- | --- | --- |
| BD.B.1 | BD.B.2 | B (main.py session-create) |
| BD.B.3 | BD.B.4 | B (session.py writes + list) |
| BD.B.5 | BD.B.6 | B (factory-translation delete) |
| BD.B.7 | BD.B.8 | B (preview route delete) |
| BD.C.1 | BD.C.2 | C (session_page title) |
| BD.C.3 | BD.C.4 | C (chat lazy-create) |
| BD.C.5 | BD.C.6 | C (status shrink + history) |
| BD.D.1 | BD.D.2 | D (patch_config + sample-config) |
| BD.E.1 | BD.E.2 | E (gate patterns) |
| BD.F.1 | BD.F.2 | F (thin factory pass-through) |
| BD.G.1 | BD.G.2 | G (agent-init identity-only) |

**11 TDD pairs.** Standalone tasks without paired impl: BD.E.3 (allowlist seed — small enough to fold into BD.E.2 but kept separate for PR-review granularity), BD.E.4 (gate-CI errand), BD.H.1 (post-merge sentinel — tests existing shape). Errands (no test commit needed): BD.0.1, BD.0.2, BD.A.1, BD.A.2.

---

## Risks & mitigations

1. **SE not yet decomposed.** Kayn is decomposing SE in parallel as of 2026-04-21. BD.B.2 and BD.B.4 target SE.A.4's signature; BD.E.2 targets SE.E.2's gate config. If SE decomposition produces a different SE.A.4 signature or a different SE.E.2 gate-file path than BD assumes, BD tasks need a minor amendment (one-line edits per task body). **Mitigation:** BD.B.2/B.4 authors coordinate with Kayn before dispatch; if mismatch, amend BD task body in-place (not a new task).
2. **S3 self-fetch not yet live.** ADR §8.2 requires confirmation from Sona before BD.F.2 merges. **Mitigation:** BD.F.2 proposes a `S1_FACTORY_THIN_PASSTHROUGH=1` flag as a kill-switch. Prod default off; stg default on. Flip to prod-on after S3 self-fetch confirmed.
3. **Migration posture — orphan live sessions.** ADR §8.1 recommends option B (orphan). If pre-deploy `SELECT count(*) FROM demo-studio-sessions WHERE status IN ('configuring','building')` returns >~5, manual outreach is needed. **Mitigation:** BD.0.1 should run the count as part of rebaseline. Not a task, but an operational checklist item — flag to Sona.
4. **Read-path latency (cold S2 cache).** Post-BD, every `/session/{id}` page render issues one GET to S2. ADR §9 accepts this; §5.2 suggests a short-TTL in-process cache. **Not in scope** for BD tasks — if p99 regresses post-deploy, file a follow-up. Do NOT pre-optimise.
5. **BD.B.4 ↔ SE.A.4 merge collision.** Both tasks touch `session.py::create_session`. If SE.A.4 lands before BD.B.4, BD.B.4 becomes an amendment on top. If BD.B.4 lands first, SE.A.4 absorbs BD's shape. Either order works as long as the two authors coordinate the branch. **Mitigation:** whichever breakdown is dispatched first becomes the anchor; the other rebases (merge — never rebase per Rule 11, so it's a merge-in).
6. **Gate false-positive in test fixtures.** The literal `"insuranceLine"` is the grep-gate trigger. Test files under `tools/demo-studio-v3/tests/` are already gate-excluded per ADR §2 Rule 4 (scope says "other than tests"), so existing test fixtures that mention `insuranceLine` in old-behaviour assertions don't trigger. BD.A.2's coverage map identifies those; they can stay until deleted naturally. **Mitigation:** confirm the gate scope excludes `tests/` in BD.E.2 impl.

---

## Open questions (OQ-BD-tasks-*)

All seven ADR-level OQs are RESOLVED. The following are task-decomposition-level residuals:

### OQ-BD-tasks-1 — BD.B.2 `insuranceLine` body rejection vs. silent drop
ADR §3.2 row 1192 says "Delete from S1 — the `insuranceLine` field is not in S2's `DemoConfig` schema at all". ADR doesn't specify whether the S1 `POST /session/new` Pydantic body should 422 on `insuranceLine` or silently drop it. BD.B.1 tests assert 422 (stricter — surfaces client errors). **Default: 422.** Flag to Sona if any known client still sends the field.

### OQ-BD-tasks-2 — Rollback on S3 5xx (BD.F.2)
ADR §5.3 pseudocode shows `transition_status(to="building")` before the S3 call. Does the task roll back to prior status on S3 5xx, or leave `building` for ops to notice? **Default: roll back to prior status** (assumes SE.A.6's `transition_status` is symmetric — confirm when SE.A.6 lands). BD.F.1 test item 3 asserts rollback. If SE.A.6 exposes no rollback path, BD.F.1 test rewrites to assert "no rollback, status stays `building`, ERROR log emitted, ops-page convention" and BD.F.2 matches.

### OQ-BD-tasks-3 — BD.E.2 gate-config file path
SE.E.2 hasn't decomposed yet; the exact gate-config file path (`scripts/grep-gate.sh` + `configs/grep-gate.yaml`? `scripts/config-boundary-gate.py`? some other shape?) is Camille's call. BD.E.2 body is written generically ("amend the SE.E.2 gate config"); exact file path is a fill-in on dispatch. **Not blocking** — resolved by a 5-minute coordination with Camille.

### OQ-BD-tasks-4 — BD.H.1 deletion-sentinel for Firestore-key entries
§3.14 includes "Firestore payload key" entries (`config`, `configVersion`). Asserting "Firestore write doesn't contain this key" requires either a fixture-captured payload or a Firestore-emulator integration test. BD.H.1 sketches "fixture-captured", but if SE.A.3/A.4 tests already capture the payload, reuse those fixtures. **Default: reuse SE.A.3/A.4 fixture if available; else capture a fresh one in BD.B.3.**

---

## Semantic gaps found in the ADR during breakdown

1. **BD.F.2 rollback posture on S3 5xx** — see OQ-BD-tasks-2. ADR §5.3 shows the happy path only; error-path rollback is unstated. Task defaults to "roll back to prior status" pending SE.A.6 confirmation.
2. **§3.2 row 1349 cold-session fallback text** — ADR says "fall back to 'New Session' on S2 404". What about S2 5xx? Same fallback? Task (BD.C.2) defaults to same fallback + WARN log. If a different semantic is wanted (e.g. 503 on the render itself), ADR needs an amendment.
3. **§3.14 refactor row "`main.session_history` brand/config read"** — the ADR talks about version history via S2's `listConfigVersions` but the S1 history endpoint doesn't currently expose version history. BD.C.6 task leaves version history as a `# TODO(SE.F)` marker and refactors only the brand-read path. **Flag: if Sona wants version history exposed in this ADR's scope, amend BD.C to add a sixth task (xfail + impl for version-listing).**
4. **ADR §3.2 row 1461–1472 `session_status` explicitly drops `factoryRunId?`** — No. ADR §5.5 says status keeps `factoryRunId?`. Reconciled: BD.C.5 test and BD.C.6 impl keep `factoryRunId` on the response. §3.2 row wording is loose ("lifecycle fields only") — interpret-aligned with §5.5 which is more explicit.
5. **§3.2 rows 1190/1250–1254 identity-field plumbing in request body** — ADR removes identity-field **persistence** on session doc, but the request body still accepts them (for agent-init). BD.B.2 task body is explicit about this. ADR could have been slightly clearer on "body accepts ≠ doc persists"; not a blocker.
6. **Migration script path for grep-gate exclusion (BD.E.3)** — ADR §2 Rule 4 exempts "tests and an explicit migration script", but ADR §8.1 recommends orphan option B (no migration script). If Duong later picks option A (backfill) or C (lazy backfill), a migration script appears and BD.E.3's allowlist needs a new entry. **Flag: if migration posture changes mid-flight, amend BD.E.3.**
7. **Pre-existing `test_no_local_validation.py:41-47`** — ADR §3.8 notes this is a pre-existing Jayce-unfinished xfail that BD.B.6 / BD.D.2 flip green. The test file name implies it asserts `sample-config.json` is gone — confirm by reading, and if it also asserts validate_v2.py is gone (likely), note both in BD.A.2 coverage map so it's clear the xfail becomes pass naturally.

---

## Test plan

Inherits ADR §Test plan I1–I4 and materialises:

- **I1 — Config-boundary gate:** BD.E.1 (gate tests) + BD.E.2/E.3 (gate config + allowlist) + BD.E.4 (CI confirmation).
- **I2 — Identity-field exclusion:** BD.B.3 (`create_session` write payload no identity fields) + BD.B.1 (`POST /session/new` flow doesn't persist identity fields).
- **I3 — Factory pass-through shape:** BD.B.5 (translation-gone regression) + BD.F.1 (thin `{sessionId}` POST shape).
- **I4 — Deleted symbols absent:** BD.B.5 / BD.B.7 / BD.D.1 per-phase tests + BD.H.1 (cross-phase sentinel against §3.14 manifest).

Rule 12 (xfail-first) applied to every BUILDER task per the pairing table above. Rule 13 (regression tests on bug fixes) does not apply — BD is pure refactor, not bug-fix.

---

## Handoff

- **Sona (work coordinator):** dispatch BD.0.1 + BD.0.2 first. Before BD.F.2 merges, confirm S3 self-fetch live on stg + prod (ADR §8.2). Run the §8.1 pre-deploy count query and decide outreach to in-flight session users (ADR recommends option B orphan). Watch Risk 5 (BD.B.4 ↔ SE.A.4 collision).
- **Kayn (SE breakdown):** coordinate SE.A.4 signature with BD.B.2/B.4; coordinate SE.F.1 agent-init wire shape with BD.G.2 (BD.G.2 ships "strip full config, send identity four"; SE.F.1 finalises the wire). Confirm SE.E.2 gate-config file path with Camille so BD.E.2 has the right target.
- **Camille (SE.E owner):** expect BD.E.2 amendment to your SE.E.2 gate-config PR — two new regexes + expanded allowlist. Co-author preferred.
- **Orianna:** BD.0.1 (line-number rebaseline) can surface drift against ADR §3's pinned `d327581`. If drift is material, ADR may need a minor patch — not a plan re-sign unless shape changes.
- **Jayce / Viktor / Viktor-flavour Sonnet builders:** tasks dispatched individually by Sona once SE/MAL breakdowns land.
- **Senna (reviewer):** the deletion manifest (BD.A.1 fixture) is your PR-review checklist; BD.H.1 is the automated sentinel.

---

## BD.0.1 Result — Line-number rebaseline

**Branch HEAD at rebaseline:** `13fc893` (feat/demo-studio-v3 after lifecycle BD amendment promotion)
**ADR pinned commit:** `d327581`
**Rebaseline date:** 2026-04-21

| ADR §3 row | file | ADR-cited line(s) | current line(s) | drift? | notes |
|---|---|---|---|---|---|
| §3.1 line 42 | session.py | 42 | 42 | n | `"config": initial_context or {}` write in `create_session` |
| §3.1 line 43 | session.py | 43 | 43 | n | `"configVersion": 1` write in `create_session` |
| §3.1 line 118–128 | session.py | 118–128 | 118–129 | y (minor) | `list_recent_sessions` identity-field reads. One extra line (line 129 is the closing of the `results.append` dict). Shape unchanged; ADR cited range is slightly narrow. Builders target 118–129 or read by symbol. |
| §3.1 line 133 | session.py | 133 | 133 | n | `_UPDATABLE_FIELDS` keep-as-is |
| §3.2 line 53 | main.py | 53 | 53 | n | `SAMPLE_CONFIG: dict = {}` module-level |
| §3.2 line 1190 | main.py | 1190 | 1190 | n | `initial_context = json.loads(json.dumps(SAMPLE_CONFIG))` deep-copy in `create_new_session_ui` |
| §3.2 line 1192 | main.py | 1192 | 1192 | n | `initial_context["insuranceLine"] = body.insuranceLine` |
| §3.2 line 1196–1201 | main.py | 1196–1201 | 1196–1201 | n | `create_session(..., initial_context=initial_context)` call block |
| §3.2 line 1219 | main.py | 1219 | 1219 | n | `send_message(..., f"Session started. Initial context: {json.dumps(initial_context)}...")` refactor target |
| §3.2 line 1250–1254 | main.py | 1250–1254 | 1250–1254 | n | `_brand/_line/_market` extraction + `seeded_context` deep-copy block in `create_new_session` (internal) |
| §3.2 line 1284 | main.py | 1284 | 1284 | n | `context_parts.append(f"Initial context: {json.dumps(seeded_context)}")` — refactor target |
| §3.2 line 1349 | main.py | 1349 | 1349 | n | `session.get("config", {}).get("brand", "New Session")` in `session_page` |
| §3.2 line 1395–1397 | main.py | 1395–1397 | 1395–1397 | n | `session.get("config", {}).get("brand"/"insuranceLine"/"market")` in `chat` lazy-create |
| §3.2 line 1439–1445 | main.py | 1439–1445 | 1439–1445 | n | Config-read body in `preview` function (decorator at 1431; ADR cited body lines which are correct) |
| §3.2 line 1461–1472 | main.py | 1461–1472 | 1461–1472 | n | `config = session.get("config")` + logos + `configVersion` reads in `session_status` (function starts at 1455) |
| §3.2 line 1987–2001 | main.py | 1987–2001 | 1987–2001 | n | `cfg = session.get("config")` + brand read in `session_history` |
| §3.2 line 2055–2065 | main.py | 2055–2065 | 2055–2065 | n | `config = d.get("config")` + identity reads in `list_sessions` |
| §3.3 line 33–129 | factory_bridge.py | 33–129 | 33–129 | n | `map_config_to_factory_params` function |
| §3.3 line 142–190 | factory_bridge.py | 142–190 | 142–190 | n | `_build_content_from_config` function |
| §3.3 line 209 | factory_bridge.py | 209 | 209 | n | `config = session.get("config", {})` in `trigger_factory` |
| §3.3 line 210–211 | factory_bridge.py | 210–211 | 210–211 | n | `factory_params = map_config_to_factory_params(config)` + `content = _build_content_from_config(...)` |
| §3.3 line 250, 253 | factory_bridge.py | 250, 253 | 250, 253 | n | `logos = config.get("logos", {})` and `bg_color = config.get("colors", {}).get("primary", ...)` |
| §3.4 line 35–63 | factory_bridge_v2.py | 35–63 | 35–63 | n | `prepare_demo_dict` function |
| §3.4 line 82 | factory_bridge_v2.py | 82 | 82 | n | `config = session.get("config", {})` in `trigger_factory_v2` |
| §3.4 line 97, 109–115 | factory_bridge_v2.py | 97, 109–115 | 97, 109–115 | n | `validate(config)` call + error handling block |
| §3.4 line 118 | factory_bridge_v2.py | 118 | 118 | n | `demo = prepare_demo_dict(config)` |
| §3.4 line 140–143 | factory_bridge_v2.py | 140–143 | 140–143 | n | `logos = demo.get("logos", {})` + `bg_color = demo.get("colors", ...)` |
| §3.5 entire file | factory_v2/validate_v2.py | entire | entire | n | File exists; 73 LOC, `validate()` function at line 24 |
| §3.6 entire file | preview.py | entire | entire | n | File exists; `render_preview` at line 16 |
| §3.7 line 94–108 | config_mgmt_client.py | 94–108 | 94–108 | n | `patch_config` function |
| §3.8 entire file | sample-config.json | entire | entire | n | File exists at tools/demo-studio-v3/sample-config.json |

**Summary:** 1 minor drift (§3.1 line 118–128 — actual range is 118–129). All other ADR-cited lines confirmed exact at `13fc893`. No function shapes changed. Builders may use symbol-based targeting (`list_recent_sessions`, `prepare_demo_dict`, etc.) and ignore the line-number discrepancy on the session.py row.

**Operational checklist item (Risk 3 from task file):** Pre-deploy count of in-flight sessions with `status IN ('configuring', 'building')` should be run before BD.B phases merge. Flag to Sona — not a BD task, but an ops gate.

## BD.0.2 Result — Worktree hygiene

Worktree `~/Documents/Work/mmp/workspace/company-os-bd-0-a` created at `chore/bd-0-a-preflight` off `feat/demo-studio-v3@13fc893`. Status clean. Branch `feat/demo-studio-v3` main worktree at `~/Documents/Work/mmp/workspace/company-os` also clean on same HEAD.
