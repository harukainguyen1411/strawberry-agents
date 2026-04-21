---
status: proposed
orianna_gate_version: 2
concern: work
complexity: normal
tests_required: true
owner: Jayce
created: 2026-04-21
tags:
  - demo-factory
  - s3
  - s4
  - project-reuse
  - trigger
  - work
---

# ADR: S3 demo-factory — project reuse and S4 auto-trigger

<!-- orianna: ok — all module and repo paths cited below (company-os/tools/demo-factory/, company-os/tools/demo-factory/main.py, company-os/tools/demo-factory/requirements.txt, company-os/tools/demo-factory/tests/test_build.py) are mmp/company-os work-workspace files; this plan is planning-only and introduces no strawberry-agents local files under those names -->
<!-- orianna: ok — HTTP route tokens (/build, /verify, /build/{buildId}, /build/{buildId}/events, /verify/{projectId}) are Cloud Run service endpoints, not filesystem paths -->
<!-- orianna: ok — Firestore collection paths (demo-factory-builds, demo-factory-builds/{buildId}, demo-factory-projects) are Firestore collection paths, not filesystem paths -->
<!-- orianna: ok — Python stdlib and library identifiers cited as inline code (asyncio.sleep, asyncio.create_task, httpx.MockTransport, unittest.mock.patch, EventSourceResponse) are Python symbols, not filesystem paths -->
<!-- orianna: ok — MIME type token (text/event-stream) is a content-type string, not a filesystem path -->

## Context

S3 (`company-os/tools/demo-factory/`) today accepts `POST /build` with a fixed `{ sessionId }` payload, always provisions a fresh Wallet Studio project for each build, and returns `{ buildId }` immediately while running the async build job. S4 (the verifier service) is never called by S3; S1 is expected to call S4 directly after detecting build completion. Neither S1 nor S4 currently has a reliable trigger path — this is a known integration gap documented in the god plan (`plans/proposed/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md` §2.2). <!-- orianna: ok -->

Two problems this ADR resolves:

1. **No project reuse.** Every build spawns a new Wallet Studio project. When a user iterates (chat, fix config, rebuild), S3 should re-use the same project rather than accumulating orphan projects. S1 needs to pass the previously-returned `projectId` back on the next `POST /build` call; S3 must honour it.

2. **No S4 auto-trigger.** S3 currently has no S4 awareness. S1 would need to poll S3 for build completion and then separately call S4. The god plan §2.2 pick (b) assigns this responsibility to S3 itself: on build success, S3 fire-and-forgets to S4 with `{ projectId, sessionId }`.

## Decision

Extend S3's `POST /build` endpoint and async build runner as follows:

**Project reuse** — accept an optional `projectId` field in the request body. If present and valid, skip provisioning and attach the build to the existing Wallet Studio project. If absent (or null), provision a new project as today. Always include `projectId` in the synchronous response alongside `buildId`, so S1 can persist it for the next iteration.

**ProjectId persistence** — persist a `projectId ↔ sessionId` mapping inside S3 (Firestore collection `demo-factory-projects` or equivalent). This is S3-internal bookkeeping; S1 is not required to read from this mapping — it receives `projectId` in the response and stores it on the session doc itself.

**S4 trigger on success** — when the async build runner reaches a terminal success state, POST to S4 with `{ projectId, sessionId }`. Per god plan §6 Q3 pick (b): trigger only on success; failed builds do not trigger S4. Fire-and-forget with retry (up to 3 attempts, exponential back-off 1s/2s/4s). All retry outcomes are logged but never propagate an exception back to the build runner — the build terminal state is `success` regardless of S4 reachability.

**Build status and event endpoints** — add `GET /build/{buildId}` returning current build status as JSON, and `GET /build/{buildId}/events` as a Server-Sent Events stream emitting build progress events. These endpoints let S1's log aggregator subscribe to S3 directly rather than polling an opaque Firestore document.

Out of scope (per §2.2 of god plan): Wallet Studio internals; S4 verifier internals; UI changes; any modification to S1 or S4.

## Phases

Phase A — xfail tests. Phase B — implementation. Phase C — smoke and lint.

## Tasks

- [ ] **T.S3.1** — Add xfail contract tests for POST /build request/response schema with optional projectId — kind: test | estimate_minutes: 25
  - Files: `company-os/tools/demo-factory/tests/test_build.py` (create if absent) <!-- orianna: ok -->
  - Cases: (a) absent projectId in request yields response with projectId + buildId; (b) present projectId echoed back in response; (c) unknown projectId yields 404; (e) existing POST /build callers omitting projectId still receive 200 (backward compat). Mark cases a-c xfail strict, referencing plan slug `s3-project-reuse-and-s4-trigger`.
  - DoD: pytest runs; xfail cases are xfail (not xpass); backward-compat case e stays green.

- [ ] **T.S3.2** — Add xfail tests for GET /build/{buildId} and SSE GET /build/{buildId}/events routes — kind: test | estimate_minutes: 20
  - Files: `company-os/tools/demo-factory/tests/test_build.py` <!-- orianna: ok -->
  - Cases: (a) GET /build/{buildId} returns 200 JSON with status field for a known build; (b) unknown buildId yields 404; (c) GET /build/{buildId}/events returns content-type text/event-stream and at least one data line. Mark all three xfail.
  - DoD: xfail cases are xfail; no existing tests broken.

- [ ] **T.S3.3** — Add xfail tests for S4 trigger behaviour — kind: test | estimate_minutes: 20
  - Files: `company-os/tools/demo-factory/tests/test_build.py` <!-- orianna: ok -->
  - Cases: (a) build reaching success terminal state causes exactly one POST to the configured S4 URL with `{ projectId, sessionId }`; (b) build reaching failure terminal state does NOT trigger S4; (c) S4 HTTP error on first attempt is retried (mock returns 500 twice then 200); (e) all retries exhausted yields build status still success — S4 unreachable does not fail the build. Mark all four xfail.
  - DoD: xfail cases are xfail; mock S4 endpoint used — no real S4 calls in unit tests.

- [ ] **T.S3.4** — Extend POST /build request model and provisioning logic — kind: feat | estimate_minutes: 30
  - Files: `company-os/tools/demo-factory/main.py` <!-- orianna: ok -->
  - Detail: add optional `projectId: str | None = None` to the Pydantic request model. In the build handler: if projectId is provided, validate it exists in the Firestore projects collection (404 on unknown); if absent, call existing provisioning path. Persist `{ projectId, sessionId, createdAt }` in Firestore on new-project path. Always include projectId in the synchronous response body alongside buildId. No change to existing buildId generation or async runner dispatch.
  - DoD: T.S3.1 xfail cases flip to passing; backward-compat case still green.

- [ ] **T.S3.5** — Add GET /build/{buildId} and GET /build/{buildId}/events route handlers — kind: feat | estimate_minutes: 35
  - Files: `company-os/tools/demo-factory/main.py` <!-- orianna: ok -->
  - Detail: GET /build/{buildId} reads build state from Firestore and returns `{ buildId, projectId, sessionId, status, createdAt, updatedAt }` as JSON; 404 on unknown buildId. GET /build/{buildId}/events opens an SSE stream using EventSourceResponse (or equivalent) that emits one event per state transition stored in the Firestore builds subcollection, holds open up to 5 min, then closes with a terminal done event. Each SSE event carries `event: build_event` and `data: <JSON>` with `{ seq, type, payload, ts }`.
  - DoD: T.S3.2 xfail cases flip to passing; manual curl smoke confirms correct content-type header.

- [ ] **T.S3.6** — Implement S4 fire-and-forget trigger in async build runner — kind: feat | estimate_minutes: 30
  - Files: `company-os/tools/demo-factory/main.py` <!-- orianna: ok -->
  - Detail: at the point the async runner writes status=success to Firestore, spawn a background task for the S4 call. The helper POSTs to `S4_VERIFY_URL` env var with `{ projectId, sessionId }` and retries up to 3 times with back-off 1s/2s/4s. All exceptions are caught and logged; none re-raised. On build failure terminal state, do not trigger S4 at all.
  - DoD: T.S3.3 xfail cases flip to passing; S4_VERIFY_URL missing yields log warning and skips gracefully without crashing.

- [ ] **T.S3.7** — Add S4_VERIFY_URL env var declaration and update dependencies if needed — kind: chore | estimate_minutes: 10
  - Files: `company-os/tools/demo-factory/main.py`, `company-os/tools/demo-factory/requirements.txt` <!-- orianna: ok -->
  - Detail: read `S4_VERIFY_URL` from environment at startup (log warning if absent). Confirm httpx or aiohttp (whichever is already present) is available for async S4 HTTP calls; add to the requirements file if missing.
  - DoD: no new import errors; existing test suite still green.

- [ ] **T.S3.8** — Full test suite pass and ruff/mypy lint — kind: test | estimate_minutes: 15
  - Files: n/a
  - Detail: run full demo-factory pytest suite and ruff check + mypy per repo config. Capture output for PR body. Manual smoke: start local uvicorn, POST /build without projectId returns `{ buildId, projectId }`.
  - DoD: all tests green; no ruff errors; mypy clean on changed files.

## Test plan

Invariants protected by this ADR:

- **Backward compatibility for existing POST /build callers** — omitting projectId from the request must continue to return 200 with buildId (now also includes projectId). No existing caller is broken.
- **projectId round-trip** — S3 always returns the projectId it used (newly provisioned or caller-supplied) in the synchronous response body. S1 can persist it without a second API call.
- **S4 triggered only on build success** — a build that reaches failure terminal state must never POST to S4. Verified by T.S3.3 case (b).
- **S4 unreachability does not fail the build** — if all S4 retry attempts fail, the build's own terminal state remains success. Verified by T.S3.3 case e.
- **SSE stream content-type** — GET /build/{buildId}/events must return a text/event-stream content-type response. Verified by T.S3.2 case (c).
- **Unknown resource yields 404** — unknown buildId on status or events route returns 404; unknown projectId on POST /build returns 404. No silent data corruption.

Test location: `company-os/tools/demo-factory/tests/test_build.py`. <!-- orianna: ok --> Framework: pytest + FastAPI TestClient. S4 endpoint mocked (no real S4 calls in unit tests). All xfail tests (T.S3.1-T.S3.3) committed before any implementation commit per Rule 12. Xfail markers reference plan slug `s3-project-reuse-and-s4-trigger`.

Regression coverage for existing callers: T.S3.1 case e and T.S3.8 full suite pass confirm no regression on the pre-existing POST /build surface.

## Open questions

1. **Firestore collection name for project mapping.** Default assumed: `demo-factory-projects`. Confirm with Duong if S3 already uses a different collection naming convention.
2. **SSE connection lifetime.** Default assumed: 5-minute max hold, then auto-close with a terminal done event. S1 reconnects if it needs further events. Adjust if S1's log aggregator prefers a different window.
3. **S4_VERIFY_URL secret management.** Assumed: Cloud Run env var set via GCP Secret Manager, same pattern as `DEMO_STUDIO_URL` in S1. Confirm if S4 has a stable Cloud Run URL at plan-promotion time or if a placeholder is acceptable.

## Handoff

- Implementer: Jayce (normal-track feature build).
- Test author: Vi (xfail scaffold + green suite verification).
- Reviewer: Senna on PR.
- Plan lives in `plans/proposed/work/`; promote via `scripts/plan-promote.sh` once Orianna signs. <!-- orianna: ok -->
- Dependency: no hard upstream dep; can implement in parallel with MCP-merge (Karma). S1-new-flow must wait for T.S3.4/T.S3.5 to be merged before integrating the projectId round-trip.
