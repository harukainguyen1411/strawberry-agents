# Partial refactor path leak — verify the full call chain from every entry point

## Date

2026-04-22

## Context

Option B refactored the `POST /session/new` + `/chat` handlers away from managed-agent architecture to a pure vanilla-API path. Viktor's impl removed the managed-agent logic from the `/chat` handler but left `create_managed_session()` being called in `POST /session/new`, which also wrote `managedSessionId` to the session record. The `/chat` handler read this field and branched to the managed-agent path whenever it was present — making ALL chat requests route through the old code path despite the refactor intent. This was the root cause of Duong's reported request_id leak and the mechanism behind Senna's C1 (auth-bypass) and C2 (multi-turn context leak) findings.

## Lesson

When refactoring away from a code path, verify the *entire call chain from every entry point*, not just the primary handler being rewritten. A legacy call surviving in an upstream entry point (e.g. session creation) will silently re-activate the old path for all downstream handlers that gate on any field the legacy call writes. The symptom (wrong behavior in handler B) will appear unrelated to the source (stale call in handler A). Explicitly audit: what does this entry point write? What downstream handlers read those fields and branch on them?

## Application

Before closing any impl wave that removes a major code path: run a grep for the removed function's name across all entry points, not just the primary file being changed. Confirm no call site writes fields that trigger the old branch. Include this as a checklist item in delegation prompts for refactor waves.
