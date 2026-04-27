---
id: 2026-04-24-sessionstart-compact-auto-continue
title: SessionStart hook — auto-continue coordinator after /compact
status: approved
concern: personal
owner: karma
complexity: quick
orianna_gate_version: 2
tdd_required: false
tests_required: false
estimate_ai_minutes: 20
touches:
  - scripts/hooks/sessionstart-coordinator-identity.sh
---

## Context

After `/compact` (and likely after `claude --resume`/`clear` too), coordinator sessions land in an idle state: Evelynn or Sona replies with the identity-resolved acknowledgement and then waits for Duong to manually type "continue". The root cause is the context string emitted by `scripts/hooks/sessionstart-coordinator-identity.sh` — it currently says `Reply only: Session resumed. Coordinator identity resolved: you are <Name>.` That "reply only" phrasing is a stop directive: the coordinator acknowledges and halts, even though the /compact summary usually contains an in-flight task.

The fix is harness-level per Duong's decision (option a): broaden the hook's additional-context to (1) keep the "do not re-read startup files" constraint and the identity pin, (2) drop the "reply only" stop phrasing, and (3) append a continue-directive that tells the coordinator to scan the TaskList for `in_progress` items, consult `agents/<coordinator>/memory/last-sessions/` if the /compact summary is thin, and resume in-flight work on the next turn without prompting Duong. Wording must not override an explicit in-session "pause" — so it's phrased as a default-resume, not a mandate.

Scope is one file. `source` branching: the bug report is about `/compact`, but the same "reply only" stop phrasing is emitted for `resume` and `clear` too — and Duong's hypothesis is correct that the idle pattern likely applies to all three. The plan applies the fix uniformly across all three sources (the hook already treats them as one branch), since the continue-directive is semantically safe for any resumed session: if there's no in-flight work, the TaskList scan finds nothing and the coordinator naturally waits for input.

## Decision

- Edit the two `_additional` strings in `sessionstart-coordinator-identity.sh` — both the resolved-identity branch and the fail-loud branch.
- Resolved branch: remove "Reply only: …"; replace with a short identity-pin line plus a continue-directive block.
- Fail-loud branch: keep the ask-Duong directive intact (no auto-continue when identity is unresolved — that's the whole point of fail-loud).
- Applies to all three sources (`resume|clear|compact`) uniformly — no source-specific branching.
- No test framework exists for hook-emitted context strings (Rule 12 TDD gate does not apply cleanly — hooks live outside the TDD-enabled services). Verification is manual: run a live `/compact` on a coordinator session and confirm next-turn behaviour is "continue in-flight work" not "idle".

## Tasks

### T1 — Rewrite resolved-identity additionalContext string

- kind: edit
- estimate_minutes: 8
- files: `scripts/hooks/sessionstart-coordinator-identity.sh` (lines 48-50)
- detail: Replace the `_additional` assignment in the resolved branch. New string conveys: (a) do not re-read startup files, (b) identity is pinned to `$_cap` and no-greeting-Evelynn default is suppressed, (c) on the next turn, scan TaskList for `in_progress` items and resume that work; if TaskList is empty or the /compact summary is thin, check `agents/<coordinator_lower>/memory/last-sessions/` for the most recent shard and resume from there, (d) if an explicit pause or handoff directive appears in the /compact summary, honour it instead of auto-continuing. Keep the sentence short and declarative — this string is injected as `additionalContext` and the coordinator reads it verbatim. Do not use the phrase "Reply only" anywhere. Preserve the `systemMessage` value (`"Resumed session — skipping startup reads."`) byte-for-byte.
- DoD: `bash -n scripts/hooks/sessionstart-coordinator-identity.sh` passes; grep confirms no remaining `Reply only` in the file; the resolved branch still emits valid JSON when stdin is `{"source":"compact"}` with `CLAUDE_AGENT_NAME=evelynn` exported.

### T2 — Leave fail-loud branch's directive intact, but align phrasing

- kind: edit
- estimate_minutes: 4
- files: `scripts/hooks/sessionstart-coordinator-identity.sh` (lines 52-54)
- detail: The fail-loud branch (no coordinator resolved) must still block auto-continue — without identity, we don't know which memory shard to read. Keep the existing "Ask Duong which coordinator this session is" directive. Minor wording alignment only: ensure the fail-loud string explicitly says "do NOT auto-continue any in-flight work" so the T1 directive above is not misread as applying here.
- DoD: Hook still emits the ask-Duong directive when no `CLAUDE_AGENT_NAME`/`STRAWBERRY_AGENT`/hint file is present; new "do NOT auto-continue" clause is visible in the emitted JSON.

### T3 — Smoke test via manual /compact

- kind: verify
- estimate_minutes: 8
- files: none (manual)
- detail: On Duong's next Evelynn or Sona session, after some in-flight work, run `/pre-compact-save` then `/compact`. Observe: resumed session should pick up the in-flight work on the first turn after /compact rather than idling. If idle persists, capture the first-turn assistant message and iterate on T1's wording. Also verify: emitting a `/compact` summary that contains an explicit "pause until Duong confirms" is still honoured (coordinator does not auto-continue past a pause).
- DoD: One successful live /compact where Evelynn (or Sona) resumes in-flight work without a manual "continue"; one verification that an explicit pause directive in the summary is honoured.

## Test plan

No automated tests — there is no test framework for hook-emitted context strings, and the behaviour under test is "Claude's next-turn response to a specific `additionalContext` payload", which is not deterministically scriptable. Rule 12 (TDD xfail gate) does not apply: hooks live in `scripts/hooks/` outside the TDD-enabled `apps/**` services, and the TDD gate targets service code.

Verification invariants, confirmed manually in T3:

1. Resolved branch: after /compact, coordinator resumes in-flight work on the next turn without user prompting.
2. Resolved branch: if /compact summary contains an explicit pause/handoff directive, coordinator honours it and does not auto-continue.
3. Fail-loud branch: when no identity resolves, coordinator asks Duong which coordinator rather than auto-continuing.
4. `systemMessage` remains `"Resumed session — skipping startup reads."` byte-identical (no other hook or doc depends on this, but preserving it avoids surprise).

## Open questions

- Should the continue-directive name the specific memory shard filename, or just the directory? Current plan: directory only (`agents/<coordinator>/memory/last-sessions/`) — coordinator picks the most recent shard by mtime. Simpler and avoids stale filename references.
- If T3 shows the directive is too passive, the next iteration may need stronger phrasing (e.g. "immediately resume" vs "on the next turn, resume"). Defer to T3 observation.

## References

- Hook: `scripts/hooks/sessionstart-coordinator-identity.sh`
- Related: `architecture/agent-network-v1/compact-workflow.md` (mechanics of /pre-compact-save + /compact)
- Rule context: Universal Invariant (none directly — this is a UX polish on the coordinator-identity hook added in a prior plan)

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has a clear owner (Karma), tightly scoped to one file, three concrete tasks with explicit DoDs and file/line references. The test-plan section correctly justifies the manual-verification approach (hooks are outside TDD-enabled services) and enumerates four verification invariants. Open questions are flagged as defer-to-observation rather than blocking. Duong pre-approved route (a).
