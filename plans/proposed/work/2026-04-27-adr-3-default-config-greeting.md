---

## slug: adr-3-default-config-greeting
title: "ADR-3 — Default config seeded on session creation, preview live at moment-zero (steps 2–3)"
project: bring-demo-studio-live-e2e-v1
concern: work
status: proposed
owner: azir
priority: P1
tier: normal
created: 2026-04-27
last_reviewed: 2026-04-27
qa_plan: required
qa_co_author: lulu
tests_required: true
architecture_impact: minor

## Context

DoD steps 2–3 of `projects/work/active/bring-demo-studio-live-e2e-v1.md`:

- **Step 2 — Session creation.** User clicks "New session"; a Firestore session doc is created; S2 has a config keyed to `sessionId`; the user lands in the SPA shell.
- **Step 3 — Default-config preview.** Preview iframe shows brand-correct content at moment-zero (first iframe load), not after a user nudge.

The wiring already exists end-to-end on `feat/demo-studio-v3` (Akali RUNWAY 2026-04-27, revision `demo-studio-00031-kc9`). The narrow gaps:

1. **Default-config source.** `tools/demo-studio-v3/main.py:1854 create_new_session_ui` already calls `_seed_s2_config(sid, request_id)` synchronously, POSTing `seed_config.DEFAULT_SEED` to S2 before the redirect. The shape (read from `tools/demo-studio-v3/seed_config.py`) is the four identity axes (`brand=Allianz`, `market=DE`, `languages=["de"]`, `shortcode=allianz`) plus `colors` (primary/secondary/accent hex) and `logos` (light/dark URLs). It validates against S2 revision `demo-config-mgmt-00014-2bn` without `force=True`. **No code change needed for the config payload itself**; D1 records the architectural decision so future plans don't redesign around it.

2. **Where S2 stores the seeded config.** S2 today is **pure in-memory** (`tools/demo-config-mgmt/main.py:84`, `_session_configs: dict[str, dict]`). PR #117 (merged) added `--min-instances=1` to S2's `deploy.sh`, but the live revision `demo-config-mgmt-00014-2bn` (2026-04-23) was deployed **before** the merge — so the running revision is still cold-start-vulnerable and any S2 redeploy mid-session wipes every active session's config. Karma owns a separate in-progress P2 plan to migrate S2 to Firestore. ADR-3 cannot promise "preview works immediately" without resolving which storage substrate underlies the seed; D2 makes the explicit pick.

3. **Preview at moment-zero.** The iframe at `studio.js:177/277` mounts on page-load with `previewFrame.src = s5Base + '/preview/' + encodeURIComponent(sessionId)`, **before** any Firestore configVersion event. S2/S5 boundary doc (`plans/implemented/work/2026-04-20-s1-s2-service-boundary.md`) says S5 reads from S2 by `sessionId` on every GET. If S2 has the seed, the iframe renders Allianz/DE content on first paint. OQ-1 (independent verification in flight via Ekko) asks whether S5 actually does this on first GET or whether it requires a `configVersion` bump to populate its cache.

### Existing-state map (ground truth)

| Surface                  | File / endpoint                                                     | Today's behavior                                                                                                                                                                                       |
| ------------------------ | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Session-create endpoint  | `tools/demo-studio-v3/main.py:1854` `POST /session/new`             | Creates Firestore doc; calls `_seed_s2_config(sid, request_id)` synchronously; returns `{sessionId, studioUrl}`. Seed call has try/except that logs `session_new_ui_seed_failed` and does not 5xx.     |
| Default-config seed body | `tools/demo-studio-v3/seed_config.py::DEFAULT_SEED`                 | Hardcoded Allianz/DE dict — brand, market, languages, shortcode, colors, logos. Validates on S2 without `force=True`.                                                                                  |
| S2 storage substrate     | `tools/demo-config-mgmt/main.py:84` `_session_configs: dict`        | Pure in-memory. Lives only in the Cloud Run instance. PR #117 set `--min-instances=1` but the live revision `00014-2bn` predates the merge — still cold-start-vulnerable until S2 redeploys.           |
| Preview iframe           | `tools/demo-studio-v3/static/studio.js:177` and `:277`              | `previewFrame.src` set on init to `s5Base/preview/{sessionId}` before any agent activity. Renders whatever S5 returns for that sessionId.                                                              |
| S5 → S2 fetch path       | (per `plans/implemented/work/2026-04-20-s1-s2-service-boundary.md`) | S5 reads latest config from S2 by `sessionId` on each `/preview/{sessionId}` GET. **OQ-1 verifies whether first GET hits S2 directly or whether S5 caches and needs a configVersion bump to populate.** |

### What's deferred

The original ADR-3 included greeting-message work (D1 system-message insert into conversation store, D3 copy spec, D4 fallback-greeting branch, T1/T2/T4/T5 + TX1/TX2/TX3 + aria-live a11y branch + reload persistence + continuity-check). Per Duong's 2026-04-27 directive ("the greeting is just icing on the cake"), all greeting work is dropped from this ADR's core scope and moved to §Future-work for a follow-up plan post-greenfield ship.

## Decision

### D1 — Default config is `seed_config.DEFAULT_SEED` (hardcoded Allianz/DE) for v1

The current `seed_config.DEFAULT_SEED` (Allianz, DE, German language, brand colors `#003781/#ffffff/#00a0e3`, light/dark logo URLs) stays as-is. **No new module, no per-org template registry, no per-user override.** Rationale:

- **DoD constraint.** The project goal is a single-user happy path that Duong tests manually. A second template would require choosing-which surface in the New Session modal — out of scope.
- **Already validated.** The existing seed passes S2 validation on revision `00014-2bn` without `force=True`. Changing the brand introduces validation risk.
- **Forward-compatible.** When v2 introduces a template registry, `DEFAULT_SEED` becomes one row in that registry; nothing changes about its consumers.

**No code change for D1.** This decision exists to lock the architecture so subsequent plans don't redesign it.

### D2 — Storage substrate: keep S2 in-memory, redeploy S2 to land `--min-instances=1`

Three options were on the table:

- **(a) In-memory + redeploy S2 with `--min-instances=1`** — quickest. Requires one S2 redeploy to land PR #117 on the live revision. After that, Cloud Run keeps one warm instance permanently; sessions survive normal traffic. **Failure modes that remain:** (i) any future S2 deploy rolls a new revision and discards `_session_configs` — every active session's config vanishes mid-flight; (ii) Cloud Run can still preempt the warm instance for maintenance (rare, undocumented but known); (iii) horizontal scale-out beyond one instance creates per-instance config inconsistency (mitigated by `--max-instances=1` if needed for v1, accepted constraint).
- **(b) Migrate S2 to Firestore** — structurally correct (Karma's P2 plan). Survives Cloud Run revision rollouts. Cost: a separate ship (Karma's plan is in-progress but not greenfield-blocking) plus refactoring S2's `_session_configs` access path. Multi-day effort; not on the critical path for the greenfield demo.
- **(c) Hybrid (in-memory cache + async Firestore mirror)** — strictly more code than (a) and strictly less correct than (b). Rejected as middle-of-the-road complexity that solves no real problem on the v1 horizon.

**Pick: (a).** Why this and not the others: Duong's directive is "simple yet clean and works". Option (a) is one redeploy of S2 — zero code change to either S2 or the studio — and gets the greenfield demo to "preview works immediately" today. Option (b) is the right long-term answer (Karma's plan owns it), but blocking ADR-3 on it lengthens the critical path by days. The accepted v1 risk is "don't redeploy S2 during a demo session"; that's an operational discipline, not a code constraint, and is acceptable for a single-user happy path. **ADR-3 takes one cross-cutting hard dependency: PR #117 (`--min-instances=1`) must be live on the running S2 revision before this ADR is considered shipped.** That requires triggering a fresh S2 deploy via `tools/demo-config-mgmt/deploy.sh` once the §Tasks land. Until that redeploy fires, the "preview works immediately" guarantee does not hold across cold starts.

### D3 — Seed must land and the iframe must render; surface seed failures explicitly

The seed call at `tools/demo-studio-v3/main.py:1854 create_new_session_ui` → `_seed_s2_config` already runs synchronously before the redirect. Iframe at `studio.js:277` mounts on page-load and S5 fetches from S2 by `sessionId`. Per the S2/S5 boundary doc, the first `/preview/{sessionId}` GET reads the latest from S2 — so once D2's substrate is live (`--min-instances=1` redeploy), the seed lands in S2 and the iframe renders the Allianz config on first paint.

**One change to today's behavior:** today's `_seed_s2_config` swallows failures (logs `session_new_ui_seed_failed` and lets session-creation return 201 anyway). Under that path, the session redirects to a SPA whose preview iframe renders S5's not-found state. This is a silent failure; the user lands on a broken experience with no signal.

**Decision:** if the seed fails after S2's existing internal retry (the `force=True` second attempt also fails), `POST /session/new` returns 5xx instead of 201 — the user sees a clear "couldn't create session, please retry" error in the existing toast/error UI. The session Firestore doc is rolled back (or marked `creation_failed`, implementer's choice based on Firestore-doc-already-written semantics). Latency cost: zero (we already wait for the seed synchronously). UX: explicit failure beats silent broken preview.

**OQ-1 fold-in (verification still in flight as of authoring).** Ekko is verifying whether S5 renders the seeded config on its first `/preview/{sessionId}` GET, or whether S5 caches and requires a `configVersion` bump to populate. If Ekko returns "first GET works" → no further change needed. If Ekko returns "needs a configVersion bump" → add a single Firestore push to `configs/{sessionId}` with `configVersion: 1` in `create_new_session_ui` immediately after the successful seed and before the redirect. No other surface changes; existing `studio.js:923` Firestore subscriber already reacts to configVersion bumps via `refreshPreview()`.

## UX Spec

### User flow

1. User signs in via Firebase / Google (existing — out of scope; Akali RUNWAY 2026-04-27 validated).
2. User in Studio shell clicks "New session". Browser POSTs `/session/new`. Server creates Firestore session doc, seeds S2, returns `{sessionId, studioUrl}` (or 5xx on seed failure per D3). ~300–600 ms happy path.
3. Browser navigates to `/session/{sessionId}`. Page renders; preview iframe mounts at `s5Base/preview/{sessionId}` and renders the seeded Allianz/DE content within ~1–2 s (S5 cold-load). `configVersion: v1` shows in the preview toolbar.
4. User types in chat. Existing flow continues.

### Component states

| State                              | Preview iframe                                       |
| ---------------------------------- | ---------------------------------------------------- |
| Page just loaded, S5 cold          | iframe mounted; existing `previewEmptyState` spinner |
| S5 returned content (happy path)   | Allianz wallet rendered; `configVersion: v1` toolbar |
| Seed failed (D3)                   | unreachable in browser — `POST /session/new` 5xx'd; user stays in Studio shell with error toast |

### Responsive behavior

No new components. Iframe inherits existing layout.

### Accessibility

Iframe `title="Demo preview"` (`studio.js:178`) unchanged. Seeded content rendered by S5 follows S5's own a11y posture (out of scope here). Error toast (D3 5xx path) inherits the existing toast component's a11y (assumed adequate; not modified by this ADR).

### Wireframe

No Figma needed. The visible surface is one iframe rendering S5 content + an existing error toast on the seed-failure path.

## Tasks

(High-level skeleton — no implementer assignment. Aphelios fills in `estimate_minutes` and substeps in breakdown.)

### T1 — Trigger fresh S2 deploy to land `--min-instances=1` on the live revision

`kind: ops`

Per D2: PR #117 is merged but the live S2 revision predates it. Run `tools/demo-config-mgmt/deploy.sh` (or equivalent) to roll a new revision. Verify via `gcloud run revisions list` that the new revision carries `--min-instances=1`. **No code change.** This is the load-bearing step — without it, ADR-3's "preview works immediately" guarantee does not hold.

### T2 — Surface seed failures from `create_new_session_ui` as 5xx

`kind: feature`

In `tools/demo-studio-v3/main.py:1854 create_new_session_ui`: replace the silent log-only branch in `_seed_s2_config`'s final-failure path with a 5xx response. Roll back (or mark `creation_failed`) the Firestore session doc that was created earlier in the handler — implementer picks the cleaner of the two given existing doc-already-written semantics. Existing toast/error UI on the studio shell shows the user the error.

### T3 — Conditional: if Ekko's OQ-1 verification returns "S5 needs configVersion bump", add Firestore configVersion push

`kind: feature` (conditional)

If and only if OQ-1 resolves negatively: in `create_new_session_ui`, immediately after the successful `_seed_s2_config` and before returning, push `{configVersion: 1}` to `configs/{sessionId}` Firestore doc. Existing `studio.js:923` subscriber will refresh the iframe. If OQ-1 resolves positively, this task is dropped.

### TX1 — xfail integration test: new session → seed in S2 → preview iframe renders

`kind: xfail`

`tools/demo-studio-v3/tests/integration/test_session_create_seed.py` (new). Per Rule 12. Asserts: after `POST /session/new` returns 201, S2 has a config keyed to `sessionId` with `brand == "Allianz"` and `market == "DE"`. Mocks Anthropic at boundary; uses test S2 instance.

### TX2 — xfail integration test: seed-failure path returns 5xx

`kind: xfail`

Same file as TX1. Mocks `config_mgmt_client.snapshot_config` to raise on both initial and `force=True` retry. Asserts `POST /session/new` returns 5xx and Firestore session doc is either absent or marked `creation_failed`.

## QA Plan

**UI involvement:** yes

Preview iframe is browser-renderable.

### Acceptance criteria

Reviewer (Senna) confirms via code-check + Akali confirms via Playwright:

- S2 live revision carries `--min-instances=1` (T1 done).
- `create_new_session_ui` returns 5xx on seed failure with rollback or `creation_failed` marker on the Firestore doc (T2).
- Preview iframe loads the seeded Allianz config visibly (S5 returns content, not 404) on the standard happy path within 4 s of redirect.

### Happy path (user flow)

The QA-side happy-path observation script (cross-references §UX Spec → User flow):

1. User signs in with Google (`missmp.eu` test account) and lands in the Studio shell.
2. User clicks "New session". `POST /session/new` returns 201; browser navigates to `/session/{sid}`.
3. Within ~4 s of redirect, the preview iframe renders Allianz/DE branded content (Allianz blue `#003781` visible, `configVersion: v1` in the toolbar).
4. No empty placeholder, no 404 error in the iframe, no spinner stuck > 4 s.

### Akali Playwright RUNWAY scope

Per the project doc §ADR-sequencing block (the 2026-04-27 RUNWAY scope-gap learning), this ADR's QA scope **mandates** sign-in via Google as part of the test path. No nonce-URL bypass.

1. **Sign-in path.** Open `feat/demo-studio-v3` Cloud Run revision URL in fresh Playwright context. Click "Sign in with Google". Complete auth with `missmp.eu` test account (creds via `tools/decrypt.sh`, never inlined). Land in Studio shell. Screenshot: post-sign-in shell.
2. **New-session creation.** Click "New session". Wait for navigation. URL matches `/session/{sid}`. Screenshot: post-redirect studio page.
3. **Preview attachment.** Within 4 s of redirect, the preview iframe shows non-empty Allianz wallet content. Screenshot: full preview panel. **Observation narrative required** (Rule 16): note Allianz blue (`#003781`) is visible and `configVersion: v1` appears in the toolbar.
4. **Failure-path validation (deferred to TX2 only).** Forcing a seed failure live would require S2 outage simulation; not feasible cleanly. `QA-Note: seed-failure 5xx UX validated via integration test TX2 only` is acceptable.

Browser isolation: incognito (fresh context per run). Env URL: feat-branch Cloud Run revision (Akali confirms with Duong before run).

QA report path: `assessments/qa-reports/2026-04-27-adr-3-default-config-greenfield.md`. Linked in PR body via `QA-Report:`.

Figma-Ref: not required. Visual-Diff: not required.

### Failure modes (what could break)

- **S2 redeploy mid-session wipes config.** Accepted operational risk per D2. No code mitigation in v1; addressed long-term by Karma's Firestore-migration plan.
- **Pre-existing sessions break.** No data migration; sessions created before this ADR are unaffected (their seed already happened or didn't, and TX1/TX2 only cover new sessions).

### QA artifacts expected

- Akali Playwright video covering steps 1–3 above.
- Per-step screenshots with observation narratives (Rule 16).
- QA report at `assessments/qa-reports/2026-04-27-adr-3-default-config-greenfield.md` linked via `QA-Report:` in PR body.

## Cross-ADR Boundaries

| Boundary                      | This ADR                          | Other ADR / plan                                                        | Contract                                                                                                                                                  |
| ----------------------------- | --------------------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Default config seeded to S2   | ADR-3 (synchronous on /session/new) | —                                                                       | After 201 from `POST /session/new`, S2 has a config keyed to `sessionId` with brand=Allianz/market=DE. Seed failure → 5xx, no orphan session.            |
| Build trigger surface         | not touched                       | `plans/approved/work/2026-04-27-deploybtn-only-build-trigger.md`         | ADR-3 finishes before any build is triggered.                                                                                                              |
| `buildId` / build progress    | not touched                       | `plans/approved/work/2026-04-27-adr-1-build-progress-bar.md`             | ADR-3 finishes before any build is triggered.                                                                                                              |
| Verify trigger / progress     | not touched                       | `plans/approved/work/2026-04-27-adr-2-verification-service.md`           | Out of phase entirely.                                                                                                                                     |
| S2 storage migration          | takes hard dep on PR #117 redeploy | Karma's in-progress P2 S2-Firestore plan                                 | ADR-3 unblocks via `--min-instances=1`; Karma's plan supersedes the in-memory substrate later. No coordination needed beyond not regressing the contract. |

## Future-work

Greeting message + a11y (aria-live announcement, conversation-store insert with `meta.origin`, fallback-on-seed-failure copy, persistence-after-reload, continuity-check) deferred to a follow-up plan once the core greenfield demo is shipped. The greeting is "icing on the cake" per Duong's directive; rebuilding it in a focused follow-up after the happy path is live carries less risk than packing it into the critical-path ADR.

## Open Questions

### OQ-1 — Does S5 render the seeded config on its **first** GET, or does it require a `configVersion` bump?

**Status: RESOLVED (2026-04-27, Ekko parallel verification).** S5 has no cache — every GET is a live HTTP fetch from S2 (`server.py` `_handle_render_preview`, no TTL, no Firestore subscription). The seed call `_seed_s2_config` is synchronous before the 201 returns and before the browser redirect fires. On the happy path, by the time `studio.js` mounts the iframe, S2 already holds `configVersion=1` and S5's first GET renders the correct Allianz brand. **No `configVersion` bump required. T3 (conditional Firestore push) is dropped from this ADR.** Failure-path runtime probe (Ekko, prod S5 GET on session `22120398cec548978bc04c4e0c3281fb`) returned `HTTP 404 NOT_FOUND` — confirming D3's fail-loud-with-rollback is the right substitute for today's silent-swallow.

## References

- `projects/work/active/bring-demo-studio-live-e2e-v1.md` — project goal, DoD, constraints.
- `plans/implemented/work/2026-04-23-agent-owned-config-flow.md` — `DEFAULT_SEED` rationale (§D3, §D7).
- `plans/implemented/work/2026-04-20-s1-s2-service-boundary.md` — S1/S2 boundary; S5/S2 fetch contract.
- `plans/approved/work/2026-04-27-deploybtn-only-build-trigger.md` — sibling ADR (deferred-to here, no overlap).
- `tools/demo-studio-v3/main.py:1854` — `create_new_session_ui` handler (extension point).
- `tools/demo-studio-v3/seed_config.py` — `DEFAULT_SEED` (read-only here).
- `tools/demo-config-mgmt/main.py:84` — S2 `_session_configs: dict` (in-memory substrate).
- PR #117 — `--min-instances=1` on S2's deploy.sh (merged; live revision predates merge — T1 redeploys).
