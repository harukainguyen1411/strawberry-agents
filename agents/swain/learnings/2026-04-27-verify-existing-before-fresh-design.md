# Verify existing-state before designing fresh, even when the brief calls something "the highest unknown"

**Date:** 2026-04-27
**Context:** ADR-2 verification service, project bring-demo-studio-live-e2e-v1.

The project doc framed the verification service as "the highest pre-build unknown" and asked me to decide extend / replace / wrap. The actual finding was inverted: the service was healthy and feature-complete; the unknown was *why nothing happens today* — four independent bugs in the live wiring (env-empty `S4_VERIFY_URL`, no `POST /verify` trigger, project_id-vs-session_id path-key mismatch, `passed/failed`-vs-`pass/fail` enum mismatch). Net effect on prod: every build today silently times out verification.

**Lesson.** When a coordinator brief tags something as "the highest unknown" or "the biggest risk," that framing is a hypothesis, not a fact. The unknown might be in the brief author's understanding, not the system. Spend 10–15 minutes on direct codebase reads (handlers, routes, env config, recent plan refs) before drafting any architectural recommendation. Yuumi's report corroborated my reads and added one bug I missed (the env-empty `S4_VERIFY_URL`) — the parallel direct-read + delegated-investigation pattern was worth the spawn cost.

**Generalisation.** Posture options framed by the brief (extend / replace / wrap) often *all* assume the existing thing is the problem. A fourth option — "the existing thing is fine; the wiring around it is broken" — should be on the table by default for any service-shaped existing surface. Surface it explicitly in the ADR's existing-state section so the reader sees the inversion.
