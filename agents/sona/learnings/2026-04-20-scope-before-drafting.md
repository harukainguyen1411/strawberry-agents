# 2026-04-20 — Confirm ownership before drafting an ADR

## What happened

When Duong asked to remove direct Firestore from Service 1 and introduce a "Session API" on Service 2, I took "Service 2 is the shared Config Mgmt service" literally and had Azir draft an ADR that *added* new `/v1/sessions*` endpoints on Service 2.

Duong's next message: "we own session, Service 2 is just for config." The whole draft had to be retargeted. New ADR kept the session on Service 1 behind a module boundary.

## Why it happened

I heard "session state management" as a *service-level* concern (where does the store live?), when Duong meant it as a *team-level ownership* concern (who owns the code?). Service 2 was the wrong answer either way — our team doesn't own Service 2, so we don't get to bolt new endpoints onto it.

## Lesson

Before drafting ADRs that add endpoints to a service, answer two questions explicitly:
1. **Who owns this service?** If not us, we don't put new endpoints on it — we consume what they expose.
2. **Is the state we're designing shared, or ours alone?** Shared state belongs on shared services; ours belongs in ours.

For Demo Studio specifically: we own **Service 1** (Content Gen / `demo-studio`). Services 2–5 are owned by other teams. Config API (`/v1/config*`, `/v1/schema`, `/logs`) is Service 2's territory — read-only to us.

## How to apply

When a design question starts with "move X out of Y" or "add an API for X":
- First response: "Who owns the target service? Is X shared or just ours?"
- Only after both are answered: draft the ADR.
- Prefer in-process modules over new services when ownership is single-team and state is single-tenant — simpler, no cross-team coordination.
