---
status: in-progress
orianna_gate_version: 2
complexity: complex
concern: work
owner: Azir
created: 2026-04-21
tags:
  - demo-studio
  - e2e
  - ship
  - integration
  - work
tests_required: true
orianna_signature_approved: "sha256:0c6587607f0e86a322039555dfcec1f1f58a26f51b08f929603fdb9695643f89:2026-04-21T10:00:40Z"
---

# ADR: Demo Studio v3 — E2E Integration and Ship Gate (v2)

<!-- orianna: ok — all bare module names and repo paths in this plan (company-os/tools/demo-studio-v3/, company-os/tools/demo-factory/, company-os/tools/demo-preview/, company-os/tools/demo-studio-mcp/, company-os/tools/demo-config-mgmt/, company-os/tools/demo-verifier/, setup_agent.py, session_store.py, managed_session_client.py) are missmp/company-os files under the work workspace; this plan is orchestration-only and introduces no strawberry-agents local files under those names -->
<!-- orianna: ok — every HTTP route token (/session/new, /session/{id}/build, /session/{id}/logs, /session/{id}/status, /api/session/{id}/iterate, /v1/config, /v1/config/{id}, /v1/preview/{id}, /v1/preview/{id}/fullview, /build, /verify, /mcp) is an HTTP path on a Cloud Run service, not a filesystem path -->
<!-- orianna: ok — every Firestore collection (demo-studio-sessions, demo-studio-sessions/{sessionId}/events/{seq}) is a Firestore collection path, not filesystem -->

## 0. Superseding note

This plan **supersedes** `plans/implemented/work/2026-04-21-demo-studio-v3-e2e-ship.md`. <!-- orianna: ok --> The prior plan was fastlaned to `implemented/` <!-- orianna: ok --> because the SE/BD/MAL/MAD ADRs it orchestrated did land — but its E2E scenarios encoded the **old flow** (brand/market passed through Slack trigger, explicit `/approve` step, S1 rendering preview in-process) which Duong has since invalidated. This v2 re-orchestrates the same four landed ADRs plus five new ADRs against the **new desired flow**. No code decisions from v1 are reversed; only the integration narrative is rewritten.

## 1. Desired E2E flow (seven steps)

1. **Empty Slack trigger.** Slack slash-command posts to slack-relay → S1 `POST /session/new` with **no** brand/market/content in `initialContext`. S1 creates a Firestore session doc in status `configuring`, spawns an Anthropic managed agent, and returns a UI URL. User clicks the link; browser lands on S1's session page. No config has been decided yet.

2. **Free-form chat configures the session.** The managed agent converses with the user in S1's chat UI. The agent is the sole driver of config state — the user never edits JSON by hand. The agent asks clarifying questions, proposes brand/market/offer choices, and waits for user confirmation at each step.

3. **After each config step, the agent writes to S2.** The agent invokes MCP tools (`set_config`, `get_config`, `get_schema`) which — post-MCP-merge — run **in-process inside S1** and proxy to S2's `/v1/config/{sessionId}`. S2 is versioned and is the single source of truth for config. S1 holds zero config state (this invariant was established by the BD ADR and must not regress).

4. **Preview is rendered by S5, iframed by S1.** S1's session page includes an `<iframe src="{S5_BASE}/v1/preview/{sessionId}">`. <!-- orianna: ok --> S5 reads config from S2 on each render. An **Open in fullview** button opens `{S5_BASE}/v1/preview/{sessionId}/fullview` <!-- orianna: ok --> in a new tab — a full-page branded render with no S1 chrome.

5. **Build is driven by S1 → S3.** User clicks **Build** in S1. S1 `POST`s to S3 `/build` with `{ sessionId, projectId? }`. S3 returns `{ projectId, buildId }` immediately and starts the async Wallet Studio build. S1 persists `projectId` on the session doc. S1 exposes `GET /session/{id}/logs` as an SSE stream that multiplexes S3 build events (pulled from S3) with S4 verification results (pulled from S4). The UI subscribes to this single SSE endpoint for all progress.

6. **S3 auto-triggers S4 on build-complete.** When S3's build finishes (success or fail), S3 itself `POST`s to S4 `/verify` with `{ projectId, sessionId }`. S1 never calls S4 directly. S1 runs a background poll of S4 `/verify/{projectId}` and, on terminal state, writes `verificationStatus` ∈ `{passed, failed}` and `verificationReport` to the session doc. The SSE `/logs` stream surfaces the same transitions.

7. **Iterate with projectId reuse.** On `verificationStatus = failed` (or when user just wants changes), user continues chatting with the agent. Agent updates config in S2. User clicks **Build** again. S1 passes the **same `projectId`** back to S3; S3 re-uses the existing Wallet Studio project rather than spawning a new one. Loop until `verificationStatus = passed` and user closes the session.

## 2. ADR breakdown

Five ADRs compose the E2E. One is in flight (Karma, MCP-merge); four are new and sequenced below. Each ADR owns its own task decomposition — Kayn/Aphelios break tasks inside each ADR file after promotion.

### 2.1 MCP-merge (in flight — **not written by this plan**)

- **Author:** Karma
- **Path:** `plans/proposed/work/2026-04-21-mcp-inprocess-merge.md` (Option A — in-process FastAPI sub-route at `POST/GET/DELETE /mcp` on S1) <!-- orianna: ok -->
- **Repo:** `company-os/tools/demo-studio-v3/` <!-- orianna: ok -->
- **Scope:** collapse standalone `demo-studio-mcp` Cloud Run service into S1; rewrite `setup_agent.py` <!-- orianna: ok --> to point managed agent at S1's own `/mcp` URL; retain TS repo as rollback surface.
- **Unblocks:** agent config writes work at all. Without this, S1's 503 MCP means the agent cannot write to S2 → nothing in the new flow works. **Gate for everything else.**

### 2.2 S3-project-reuse-and-s4-trigger

- **Repo:** `company-os/tools/demo-factory/` <!-- orianna: ok -->
- **Scope:**
  - Accept optional `projectId` on `POST /build`. If present, re-use that Wallet Studio project; if absent, provision new and return it in the response body.
  - Persist `projectId ↔ sessionId` mapping (S3-internal; Firestore or equivalent).
  - On build terminal state (success or failure), S3 `POST`s to S4 `/verify` with `{ projectId, sessionId }`. Fire-and-forget with retry; failures logged but do not fail the build.
  - Add `GET /build/{buildId}` and `GET /build/{buildId}/events` (SSE) for S1's log aggregator to consume.
- **Out of scope:** Wallet Studio internals; S4 internals; any UI changes.

### 2.3 S5-fullview

- **Repo:** `company-os/tools/demo-preview/` <!-- orianna: ok -->
- **Scope:** add `GET /v1/preview/{id}/fullview` that serves a full-page HTML render of the preview (no S1 chrome, no iframe wrapper, branded). Reads config from S2 same as `/v1/preview/{id}`. CORS already permits iframe from S1; fullview is a plain top-level page.
- **Trivial ADR.** Jayce can land this in a single PR.

### 2.4 S1-new-flow

- **Repo:** `company-os/tools/demo-studio-v3/` <!-- orianna: ok -->
- **Scope (UI + backend):**
  - **Slack trigger:** `POST /session/new` accepts empty `initialContext`; remove brand/market/content propagation from slack-relay → S1 path. Update slack-relay payload contract.
  - **Delete `/approve` dead route** and any UI button wiring (route file is already deleted; confirm no call sites remain).
  - **Iframe S5:** replace S1's deleted `/session/{id}/preview` iframe src with `{S5_BASE}/v1/preview/{sessionId}`. <!-- orianna: ok --> Add **Open in fullview** button → new tab to `{S5_BASE}/v1/preview/{sessionId}/fullview`. <!-- orianna: ok -->
  - **Session doc fields:** extend `session_store.py` <!-- orianna: ok --> schema with `projectId: str | None`, `verificationStatus: Literal['pending','passed','failed'] | None`, `verificationReport: dict | None`, `lastBuildAt: datetime | None`. Migrate existing docs (null defaults).
  - **projectId capture:** on `POST /session/{id}/build`, read `projectId` from S3's response and persist via `session_store.transition_status` side-channel (or dedicated setter); on subsequent builds, pass the stored `projectId` back to S3.
  - **SSE logs endpoint:** `GET /session/{id}/logs` streams a merged view of S3 build events (pulled from S3 SSE) plus S4 verification poll results. Single client subscription surface; no direct UI→S3 or UI→S4 calls.
  - **S4 polling loop:** background task (per active session) polls S4 `/verify/{projectId}` until terminal, writes `verificationStatus` + `verificationReport` to session doc, emits to SSE stream.
  - **Iterate UX:** when `verificationStatus` terminal, UI shows result and re-enables the chat + Build button. No separate "iterate" endpoint — same `POST /session/{id}/build` is idempotent-by-projectId.
- **Dependency:** MCP-merge must land first (agent config writes must work); S3-changes must land first (projectId in `/build` response + S3→S4 trigger is assumed).

### 2.5 (implicit) Integration smoke — covered by §4 below

## 3. Dependency DAG

```
MCP-merge (Karma) ──┐
                    ├──▶ S1-new-flow (Viktor) ──▶ Integration smoke (Heimerdinger + Akali)
S3-reuse+trigger ───┤                         ▲
       (Jayce)      │                         │
                    └──▶ S5-fullview (Jayce) ─┘
```

Critical path: **MCP-merge and S3-changes in parallel** → unblock S1-new-flow → S5-fullview can land any time after S3 is green on staging → integration smoke closes the gate.

Parallelism notes:
- S5-fullview has **no hard dep** on MCP-merge or S3; it can be written and merged any time. It only becomes *observable* once S1-new-flow iframes it.
- S1-new-flow's UI shell (iframe-S5, empty-session trigger, deleted `/approve`) can start **before** S3-changes land, gated by an env flag that stubs the S3 response. Full integration waits for S3.

## 4. E2E smoke v2 (8 scenarios)

Replaces all scenarios in the superseded plan. Each runs in staging against real S2/S3/S4/S5 + Anthropic managed agents.

1. **Empty-session Slack trigger.** Slash command → S1 creates session with `initialContext = {}`; UI loads with no pre-filled brand/market; agent's first message is a generic greeting.
2. **Agent config via MCP → S2.** Agent calls `set_config` for brand name; S2 `/v1/config/{sessionId}` reflects the write within 2s; `get_config` round-trips correctly.
3. **Preview iframe loads from S5.** After ≥1 config write, iframe src resolves to `{S5_BASE}/v1/preview/{sessionId}` <!-- orianna: ok --> and paints (status 200, non-empty DOM).
4. **Open in fullview new-tab.** Clicking button opens `/v1/preview/{id}/fullview` in new tab; page renders full-bleed with no S1 chrome.
5. **Build → S3 → S4 round-trip (cold).** First build from session: S3 returns fresh `projectId`; persisted on session doc; S3 auto-POSTs to S4; SSE `/logs` surfaces both build events and eventual verification result.
6. **Verification pass surfaces in UI.** `verificationStatus = passed` appears in UI via SSE within 5s of S4 terminal; session doc reflects same.
7. **Iterate with same projectId (warm).** After a first build, second `POST /session/{id}/build` sends the stored `projectId` to S3; S3 response echoes same `projectId` (no new WS project); build completes; second S4 verification runs against same project.
8. **Verification fail → iterate → pass.** Force a failing config; see `verificationStatus = failed`; chat with agent to fix; rebuild; same projectId; verification passes. End-to-end loop observable in SSE.

All 8 must be green on staging before the ship gate flips.

## 5. Ship gate

Flip `MANAGED_AGENT_DASHBOARD=1` in prod **only** when:

- [ ] All five ADRs (MCP-merge, S3, S5, S1-new-flow) are `implemented/` <!-- orianna: ok --> with PRs merged to their respective `main` branches.
- [ ] The four landed v1 ADRs (SE, BD, MAL, MAD) remain green — no regression on their existing smoke.
- [ ] All 8 §4 scenarios green on staging, run back-to-back within a single session, video recorded (Rule 16).
- [ ] Akali's UI regression pass green against Figma for: session page (empty state), chat + MCP tool-call indicators, iframed preview, fullview new-tab, build progress + SSE log view, verification pass/fail states.
- [ ] Prod smoke runbook (Heimerdinger) executes Scenarios 1, 3, 5, 6 against prod within 15 min of flip; rollback script ready if any red.
- [ ] Rollback path verified: `MANAGED_AGENT_DASHBOARD=0` restores prior-week behavior (dashboard hides the Managed Agents tab; no data loss).

## 6. Open questions

1. **SSE authN for `/session/{id}/logs`?** — (a) reuse S1's existing session cookie; (b) short-lived signed token in query string; (c) no auth (session ID is the capability). **Pick: (a).** Matches S1's current auth posture; avoids token-rotation complexity.

2. **Does S5 pull config from S2 on every request, or cache?** — (a) no cache; (b) 5s in-process LRU; (c) push-invalidation from S2 webhook. **Pick: (b).** Preview is read-heavy; 5s staleness is acceptable; webhooks are out of scope.

3. **S3→S4 trigger on build *failure* — should S4 still verify?** — (a) always; (b) only on build success; (c) S3 sends both but S4 short-circuits failed builds. **Pick: (b).** A failed build produces no deployable artifact; verifying nothing wastes S4 cycles and confuses users.

4. **projectId lifetime on `verificationStatus = passed`** — (a) retained forever on session doc; (b) cleared on session `completed`; (c) archived to a separate collection. **Pick: (a).** Session docs are already retained; no separate lifecycle needed; enables audit.

5. **Does the managed agent see verification results?** — (a) agent polls session doc each turn; (b) S1 pushes verification report into agent's context via MCP resource; (c) agent is unaware, user re-states problems in chat. **Pick: (b).** Closes the loop — agent can propose concrete fixes based on the report. Adds a new MCP resource `get_last_verification` (Karma's ADR can absorb this or it goes in S1-new-flow).

## 7. Handoff

Each ADR is created (if not already) in `plans/proposed/work/` <!-- orianna: ok --> and owned by one subagent. Evelynn assigns post-Orianna-signature; the names below are Azir's recommended routing based on complexity.

| ADR | Owner | Complexity | Notes |
|---|---|---|---|
| MCP-merge | **Karma** (in flight) | complex | Already being written; do not touch |
| S3-project-reuse-and-s4-trigger | **Jayce** | normal | Jayce writes the ADR and drives impl |
| S5-fullview | **Jayce** | trivial | Same owner; small enough to bundle, but separate ADR for Orianna tracking |
| S1-new-flow | **Viktor** | complex | Multi-surface: slack-relay contract, SSE, Firestore migration, polling loop, UI |
| MCP-merge impl (post-ADR) | **Viktor** | complex | Handoff from Karma once ADR signs through `approved/` <!-- orianna: ok --> |
| Test plans (S3, S5, S1-new-flow) | **Xayah** (unit/contract) + **Caitlyn** (E2E) | — | Xayah covers per-service xfail + regression; Caitlyn writes the Playwright flows for the 8 §4 scenarios |
| Deploy + smoke orchestration | **Heimerdinger** | — | Runs §4 on staging; writes the prod flip runbook + rollback drill |
| UI regression pass (Rule 16) | **Akali** | — | Full Playwright flow with video + screenshots, diff against Figma; report in `assessments/qa-reports/` <!-- orianna: ok --> |

**Explicit non-task:** This plan does not decompose any ADR into tasks. Each ADR above, once through `proposed/` → `approved/` via Orianna, gets its own `-tasks.md` shard from Kayn (for Opus-owned ADRs) or Aphelios (for Sonnet-owned). <!-- orianna: ok --> This plan is orchestration only.

## Test plan

This plan is orchestration-only; implementation-level unit and contract tests live inside each ADR (S3-reuse+trigger, S5-fullview, S1-new-flow, MCP-merge). The **orchestration-level** test obligations — owned by this plan and gated by §5 ship gate — are:

- **E2E smoke (Caitlyn).** Playwright suite encoding all 8 scenarios from §4, driven against staging with real S2/S3/S4/S5 + Anthropic managed agents. Suite must run back-to-back in one session, video recorded per Rule 16, and pass before flag flip.
- **UI regression (Akali).** Full Playwright flow against Figma for session page empty state, chat + MCP tool-call indicators, iframed preview, fullview new-tab, build SSE log view, verification pass/fail states. Report in `assessments/qa-reports/`. <!-- orianna: ok -->
- **Contract tests (Xayah).** Per-service xfail + regression: S3 `projectId` round-trip on `/build`, S3→S4 `/verify` trigger on terminal state, S5 fullview route content-type + 200, S1 SSE `/session/{id}/logs` multiplex, S1 session-doc migration (null defaults for new fields).
- **Prod smoke (Heimerdinger).** Scenarios 1, 3, 5, 6 from §4 re-run against prod within 15 min of `MANAGED_AGENT_DASHBOARD=1` flip; rollback script on any red.
- **Regression coverage for v1 ADRs.** SE/BD/MAL/MAD existing smoke must remain green — Xayah owns the re-run before ship gate.

All suites must be green simultaneously on staging within a single pre-flip window; no partial-green flip.

## Test plan (Xayah — complex-track E2E matrix)

Authored by Xayah 2026-04-21 per D1A rule (inline; no sibling `-tests.md`). This matrix is the detailed gate between merged-code and the `MANAGED_AGENT_MCP_INPROCESS=1` flag flip. It operationalizes the §4 smoke (8 scenarios) plus the fault-injection and rollback coverage that the smoke alone does not exercise. Owner: Xayah (plan). Implementer: Rakan (complex fixtures, multi-service harness, fault injectors). CI gates: `e2e.yml` <!-- orianna: ok --> (Rule 15, required on PR → main of any ADR that touches §2.1–§2.4), `tdd-gate.yml` <!-- orianna: ok --> (Rule 12, xfail required on feature branches), prod smoke (Rule 17) for TS.GOD.25–27 only.

**Environment axioms.** All cases below run against **staging** unless explicitly marked prod. Staging harness provisions: isolated Firestore namespace per test session; Anthropic managed-agent staging account with key scoped to test; S2/S3/S4/S5 staging Cloud Run revisions pinned to branch SHAs under test; slack-relay stub (no real Slack webhook). MCP bearer token is a per-run secret injected via `tools/decrypt.sh` (Rule 6 — never echoed).

**Claim-contract suppressors (Orianna):** all bare module/route tokens referenced below — `setup_agent.py` <!-- orianna: ok -->, `session_store.py` <!-- orianna: ok -->, `managed_session_client.py` <!-- orianna: ok -->, `/mcp` <!-- orianna: ok -->, `/session/new` <!-- orianna: ok -->, `/session/{id}/build` <!-- orianna: ok -->, `/session/{id}/logs` <!-- orianna: ok -->, `/api/session/{id}/iterate` <!-- orianna: ok -->, `/v1/config` <!-- orianna: ok -->, `/v1/config/{id}` <!-- orianna: ok -->, `/v1/preview/{id}` <!-- orianna: ok -->, `/v1/preview/{id}/fullview` <!-- orianna: ok -->, `/build` <!-- orianna: ok -->, `/verify` <!-- orianna: ok -->, `MANAGED_AGENT_MCP_INPROCESS`, `demo-studio-sessions` <!-- orianna: ok --> — match the parent plan's pattern and are claim-suppressed via the parent plan's opening suppressor block (lines 20–22). No new bare names introduced by this section.

**Case id | scope | invariant | setup | assertion | CI gate | estimate_minutes**

| ID | Scope | Invariant | Setup | Assertion | CI gate | est |
|---|---|---|---|---|---|---|
| **TS.GOD.1** | E2E (scenario 1) | Empty Slack trigger creates session in `configuring` with `initialContext = {}` and no pre-filled brand/market | POST slack-relay stub with slash-command payload carrying no brand/market/content fields | Firestore doc exists with `status = configuring`, `initialContext = {}`, `projectId = null`, `verificationStatus = null`; UI URL returned; GET UI URL returns 200 and chat shows generic greeting (no brand-specific copy) | e2e.yml <!-- orianna: ok --> | 25 |
| **TS.GOD.2** | E2E (scenario 2) | Managed agent drives config state; user never edits JSON directly | Fresh session from TS.GOD.1; Playwright types "use brand Acme" in chat | Agent invokes `set_config` MCP tool within 10s; S2 `/v1/config/{sessionId}` reflects `brand.name == "Acme"` within 2s of tool-call; `get_config` round-trips the same value; S1 session doc holds **zero** config fields (only `sessionId`, `status`, `projectId`, `verificationStatus`, etc.) — BD invariant | e2e.yml <!-- orianna: ok --> | 40 |
| **TS.GOD.3** | Integration | MCP server is mounted in-process inside S1 at `/mcp` when `MANAGED_AGENT_MCP_INPROCESS=1` | Boot S1 with flag=1; curl `GET /mcp/healthz` (or equivalent MCP handshake) from inside the S1 pod | 200 response from S1's own port; **no** network hop to external demo-studio-mcp Cloud Run service (assert via S1 egress log absence); MCP session cookie/bearer validates | tdd-gate.yml <!-- orianna: ok --> + e2e.yml <!-- orianna: ok --> | 30 |
| **TS.GOD.4** | Integration (auth) | MCP bearer token length/regex validated before tool dispatch | POST `/mcp` with bearer token of length < min | 401 with error code `invalid_token_length`; no tool invocation logged; no S2 write | tdd-gate.yml <!-- orianna: ok --> | 15 |
| **TS.GOD.5** | Integration (auth) | MCP bearer token regex rejects malformed tokens | POST `/mcp` with bearer matching length but failing regex (e.g., non-hex chars) | 400 with `malformed_token`; no tool invocation; no S2 write | tdd-gate.yml <!-- orianna: ok --> | 15 |
| **TS.GOD.6** | Integration (auth) | Valid bearer token admits tool call | POST `/mcp` with well-formed bearer, `set_config` body | 200; S2 reflects write | tdd-gate.yml <!-- orianna: ok --> | 10 |
| **TS.GOD.7** | E2E (scenario 3) | S5 iframe re-renders after config write | From TS.GOD.2 end-state, wait 5s (S5 LRU ttl per §6 Q2); reload iframe | iframe src resolves to `{S5_BASE}/v1/preview/{sessionId}` <!-- orianna: ok -->; response 200 with non-empty DOM containing `brand.name == "Acme"` branding | e2e.yml <!-- orianna: ok --> | 20 |
| **TS.GOD.8** | E2E (scenario 4) | Fullview opens in new tab as full-bleed doctype shell, no S1 chrome | Click "Open in fullview" button | New tab navigates to `/v1/preview/{sessionId}/fullview` <!-- orianna: ok -->; response is `text/html` <!-- orianna: ok --> with `<!doctype html>` and **no** S1 nav/chrome elements; content includes config brand | e2e.yml <!-- orianna: ok --> | 20 |
| **TS.GOD.9** | E2E (scenario 5) | Cold build: S3 returns fresh `projectId` and persists to session doc | Click Build from session with no prior `projectId` | S1 `POST /session/{id}/build` → S3 `/build`; S3 response body contains new `projectId`; session doc transitions `projectId: null → <pid>`; `buildId` surfaces to SSE within 5s | e2e.yml <!-- orianna: ok --> | 35 |
| **TS.GOD.10** | E2E (scenario 5 cont.) | S3 auto-triggers S4 on build-complete (success only, per §6 Q3) | From TS.GOD.9, let build run to success | S4 receives `POST /verify` with `{ projectId, sessionId }` within 30s of build terminal; S1 did **not** call S4 directly (assert from S1 egress logs); SSE `/logs` stream multiplexes both build events and eventual verification start | e2e.yml <!-- orianna: ok --> | 35 |
| **TS.GOD.11** | E2E (scenario 5 neg) | S3 does **not** trigger S4 when build fails | Force build failure via fixture config | S4 receives **zero** `/verify` calls for this `projectId`; session doc `verificationStatus` remains null; SSE stream surfaces `build: failed` but no verification events | e2e.yml <!-- orianna: ok --> | 25 |
| **TS.GOD.12** | E2E (scenario 6) | Verification pass surfaces in UI via SSE within 5s of S4 terminal | From TS.GOD.10, let S4 run to pass | Session doc `verificationStatus = passed`, `verificationReport` populated; SSE client receives `verification: passed` event within 5s of S4 terminal (measured from S4 log timestamp); UI re-enables chat + Build button | e2e.yml <!-- orianna: ok --> | 30 |
| **TS.GOD.13** | E2E (scenario 7) | Iterate warm-path reuses same `projectId`; S3 does not spawn new WS project | From TS.GOD.12 end-state, chat to change config, click Build again | S1 `POST /session/{id}/build` sends stored `projectId`; S3 response echoes **same** `projectId` (not new); Wallet Studio project count unchanged (assert via S3 internal mapping); second build event stream begins | e2e.yml <!-- orianna: ok --> | 35 |
| **TS.GOD.14** | E2E (scenario 8) | Fail → iterate → pass loop end-to-end | Force failing config on first build; on `verificationStatus = failed`, chat with agent to fix, rebuild | First verification = failed; second build uses same `projectId`; second verification = passed; SSE surfaces entire loop; session doc final state reflects pass | e2e.yml <!-- orianna: ok --> | 50 |
| **TS.GOD.15** | Integration (agent loop) | Agent sees verification report via MCP resource `get_last_verification` (§6 Q5 pick b) | After TS.GOD.12, agent's next turn calls `get_last_verification` tool | Tool returns `verificationReport` matching session doc; agent's subsequent message references specific findings from report (LLM output assertion: contains at least one field name from report) | e2e.yml <!-- orianna: ok --> | 30 |
| **TS.GOD.16** | Fault injection | S2 503 during agent config write — agent surfaces error, does not corrupt session | Mid-chat, toxiproxy-drop S2 `/v1/config/{sessionId}` writes to return 503 for 30s | MCP `set_config` tool-call returns error to agent; agent re-tries up to 2x then surfaces failure in chat; session doc unchanged; after S2 recovery, next `set_config` succeeds with no stale state | e2e.yml <!-- orianna: ok --> | 40 |
| **TS.GOD.17** | Fault injection | S3 500 on `/build` — S1 surfaces failure, session remains iterable | Mock S3 to return 500 on first `/build` call | S1 returns 5xx to UI with user-readable error; session doc `projectId` stays null; `status` not advanced; UI Build button re-enabled; second click (after mock cleared) succeeds | e2e.yml <!-- orianna: ok --> | 30 |
| **TS.GOD.18** | Fault injection | S4 verification timeout — S1 polling loop eventually surfaces `verificationStatus = failed` with timeout reason | Mock S4 `/verify/{projectId}` to hang past S1 polling timeout (configured cutoff) | S1 polling loop terminates at cutoff; writes `verificationStatus = failed`, `verificationReport.reason = "timeout"`; SSE surfaces event; no orphan poll task left running (assert via pod metric) | e2e.yml <!-- orianna: ok --> | 35 |
| **TS.GOD.19** | Fault injection | Managed-agent 429 during chat — S1 backs off, user sees retry UX | Throttle Anthropic managed-agent endpoint to 429 for 60s via fixture | S1 backs off per Retry-After header; UI shows "agent busy, retrying" state; after throttle clears, conversation resumes without session doc corruption | e2e.yml <!-- orianna: ok --> | 30 |
| **TS.GOD.20** | Fault injection | Anthropic API hard-down during session creation — S1 fails fast, no zombie session | Mock Anthropic API to return 503 on all calls | `POST /session/new` returns 5xx to slack-relay; no Firestore session doc created (or doc created+tombstoned cleanly, pick per S1-new-flow impl); no orphan managed-agent handle | e2e.yml <!-- orianna: ok --> | 25 |
| **TS.GOD.21** | Fault injection | MCP mount fails at S1 lifespan startup — S1 process fails closed, does not accept traffic | Inject mount-failure in S1 FastAPI lifespan (e.g., inject import error into MCP sub-router at boot) | S1 exits non-zero OR fails readiness probe within 30s; Cloud Run does not mark revision healthy; no `/session/new` accepted; Stackdriver error logged with root cause | tdd-gate.yml <!-- orianna: ok --> + e2e.yml <!-- orianna: ok --> | 45 |
| **TS.GOD.22** | Fault injection | MCP in-process call raises — S1 returns 5xx to agent, no S2 partial write | Inject `set_config` handler to raise mid-call after validation | MCP returns 500 to managed-agent; S2 receives **zero** partial writes (verify via S2 request log); session doc unchanged; agent retry path engages | e2e.yml <!-- orianna: ok --> | 30 |
| **TS.GOD.23** | Rollback E2E | Flipping `MANAGED_AGENT_MCP_INPROCESS=0` restores traffic to external `mcps/` <!-- orianna: ok --> service (hybrid period) | On a running session, flip env flag on S1 revision via Cloud Run revision update; do **not** redeploy | Next managed-agent MCP call routes to external demo-studio-mcp Cloud Run URL (assert via egress log); S1's own `/mcp` returns 404 or disabled; existing session continues functioning; no data loss in session doc | e2e.yml <!-- orianna: ok --> | 40 |
| **TS.GOD.24** | Rollback E2E | Rollback preserves in-flight session state | From TS.GOD.23, complete Build + verify after flag flip | Same session doc transitions through `projectId` set → verification pass exactly as pre-flip; Firestore history shows continuous sessionId (no fork) | e2e.yml <!-- orianna: ok --> | 30 |
| **TS.GOD.25** | Prod smoke (Rule 17) | Scenario 1 (empty trigger) runs on prod within 15 min of flag flip | Post-flip, run slack-trigger against prod slack-relay | Same assertions as TS.GOD.1 against prod Firestore + prod S1 | prod smoke (no CI gate; Heimerdinger manual runbook) | 15 |
| **TS.GOD.26** | Prod smoke (Rule 17) | Scenario 3 (iframe loads) runs on prod | Post TS.GOD.25, trigger at least one `set_config` via chat, load preview iframe | Same assertions as TS.GOD.7 against prod S5 | prod smoke | 15 |
| **TS.GOD.27** | Prod smoke (Rule 17) | Scenarios 5+6 (cold build + pass) run on prod | Continue from TS.GOD.26 to Build + verification | Same assertions as TS.GOD.9, TS.GOD.10, TS.GOD.12 against prod S3/S4 | prod smoke + rollback script armed | 40 |
| **TS.GOD.28** | Regression | v1 ADRs (SE, BD, MAL, MAD) smoke suites remain green on staging | Re-run each landed ADR's existing smoke against staging on the same branch as §2.1–§2.4 merges | All v1 ADR smoke green with zero new failures; Xayah audit report attached to ship-gate checklist | e2e.yml <!-- orianna: ok --> | 30 |
| **TS.GOD.29** | Contract | Session-doc schema migration handles null defaults for existing docs | Seed Firestore with pre-migration session docs (no `projectId`/`verificationStatus`/`verificationReport`/`lastBuildAt` fields); boot S1 with §2.4 code | Reads of legacy docs succeed; null defaults returned for new fields; no write amplification (migration is lazy); writes of new fields persist correctly | tdd-gate.yml <!-- orianna: ok --> | 25 |
| **TS.GOD.30** | Contract | `/session/{id}/logs` SSE multiplex does not drop events under back-pressure | Generate 100 S3 build events + 10 S4 verification transitions in rapid succession while 1 slow SSE client consumes | Client receives all 110 events in monotonic order; no dropped sequence numbers; server-side queue bounded (no unbounded memory growth — assert via pod memory metric cap) | e2e.yml <!-- orianna: ok --> | 35 |

**Total cases: 30.** E2E + scenario coverage: 14 (TS.GOD.1/2/3/7/8/9/10/11/12/13/14/15 + prod 25–27). Fault injection: 7 (TS.GOD.16–22). Rollback: 2 (TS.GOD.23–24). Contract: 4 (TS.GOD.4/5/6 auth + TS.GOD.29 migration + TS.GOD.30 SSE). Regression: 1 (TS.GOD.28). Prod smoke: 3 (TS.GOD.25–27).

**Total estimated: ~885 minutes for Rakan to author + land.** Expect parallelization across ADR branches for TS.GOD.4–6 (MCP-merge PR), TS.GOD.9–13/29 (S3 + S1-new-flow PRs), TS.GOD.7/8 (S5 PR); fault-injection + rollback cases land against the integration branch `feat/demo-studio-v3` <!-- orianna: ok --> only after all four PRs merge.

### Dependencies flagged

- **D1** — TS.GOD.3 (in-process MCP mount assertion) requires MCP-merge ADR `implemented/` <!-- orianna: ok --> and §2.1's Option A (in-process sub-route) landed; Option B (shared-container sidecar) would invalidate the assertion wording. Rakan must block this case on Karma's ADR signature.
- **D2** — TS.GOD.13 (warm-path `projectId` reuse) requires S3-reuse ADR `implemented/` <!-- orianna: ok --> with the `projectId ↔ sessionId` persistence live. If §2.2 lands with in-memory mapping only, the case must assert survival across S3 revision restart.
- **D3** — TS.GOD.15 (`get_last_verification` MCP resource) depends on §6 Q5 pick (b) landing in either Karma's MCP-merge ADR or Viktor's S1-new-flow ADR. Rakan holds this case until the owner is decided; Xayah flags it as **blocked-pending-ownership**.
- **D4** — TS.GOD.18 (S4 polling timeout) requires S1-new-flow ADR to define an explicit polling cutoff. If not defined, Rakan files a follow-up question on Viktor's ADR before authoring.
- **D5** — TS.GOD.21 (lifespan-startup fault) requires `MANAGED_AGENT_MCP_INPROCESS=1` code path to fail-closed at lifespan. If Karma's ADR opts for fail-open (soft-disable MCP, continue serving session UI), assertion flips to "UI serves read-only, no chat, with visible degraded banner"; update case on ADR ambiguity resolution.
- **D6** — TS.GOD.23/24 (rollback E2E) require external `mcps/` <!-- orianna: ok --> service to remain deployed during hybrid period per Karma's ADR rollback stance. If TS repo is retired in same window, cases must be deleted and a new case added asserting flag=0 fails closed with user-readable message.
- **D7** — TS.GOD.25–27 (prod smoke) require Rule 17 post-deploy smoke infrastructure (rollback script + alerting) to be live; Heimerdinger's §5 runbook is the owner. Xayah will not author prod cases until runbook exists.
- **D8** — All E2E cases (TS.GOD.1–15, 23–24, 30) require Rule 16 UI regression harness availability (Akali's Playwright + video + Figma diff) per §5 ship gate. Rakan coordinates fixture sharing with Akali to avoid duplicate Playwright setup.
- **D9** — Signature invalidation: this Test-plan section was appended **after** Orianna's signature (frontmatter line 15, sha256:0c65…). The body-hash is now stale. Xayah does **not** re-sign (per D1A protocol); Azir/Evelynn/Sona must run demote → Orianna re-fact-check → re-sign → promote cycle before next phase transition.

## Tasks

Orchestration-level coordination only. No ADR decomposition here (each ADR owns its own `## Tasks` via Kayn/Aphelios post-approval, per §7).

- [ ] **T.COORD.1** — Resolve §6 open questions 1–5 with Duong and record picks in this file. kind: coord | estimate_minutes: 30
- [ ] **T.COORD.2** — Confirm MCP-merge ADR is Orianna-signed through approved before S1-new-flow impl begins (critical path gate). kind: coord | estimate_minutes: 10 <!-- orianna: ok -->
- [ ] **T.COORD.3** — Confirm S3-project-reuse-and-s4-trigger ADR is proposed + signed before S1-new-flow contract tests are authored. kind: coord | estimate_minutes: 10
- [ ] **T.COORD.4** — Sequence ADR merges per §3 DAG; spawn implementers per §7 handoff table after each ADR promotion. kind: coord | estimate_minutes: 20
- [ ] **T.COORD.5** — Run §5 ship-gate checklist review before flipping MANAGED_AGENT_DASHBOARD=1 in prod. kind: coord | estimate_minutes: 30
- [ ] **T.COORD.6** — Post-flip, schedule retrospective and archive this plan to implemented. kind: coord | estimate_minutes: 15 <!-- orianna: ok -->

## Out of scope (recorded explicitly so it does not drift back in)

- Any re-architecture of S2 (config store) — unchanged.
- Any S4 verifier internals — S4 already exists; we are only wiring it.
- Replacing or retiring the managed agent — decided, stays.
- Deleting `demo-studio-mcp` TS repo — Karma's ADR retains it as rollback; separate follow-up later.
- Per-user auth or multi-tenancy on sessions — current single-session-per-Slack-trigger model stands.
