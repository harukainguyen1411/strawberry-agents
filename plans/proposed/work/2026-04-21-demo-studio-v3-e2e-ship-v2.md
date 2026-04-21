---
status: proposed
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
orianna_signature_approved: "sha256:0c6587607f0e86a322039555dfcec1f1f58a26f51b08f929603fdb9695643f89:2026-04-21T09:56:29Z"
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
- **Path:** `plans/proposed/work/2026-04-21-mcp-inprocess-merge.md` (Option A — in-process FastAPI sub-route at `POST/GET/DELETE /mcp` on S1)
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
