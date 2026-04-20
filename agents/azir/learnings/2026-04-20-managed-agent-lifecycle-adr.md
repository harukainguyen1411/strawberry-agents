# Managed-Agent Lifecycle ADR — gotchas

## Anthropic SDK docs leave two real gaps

Fetched `platform.claude.com/docs/en/managed-agents/sessions` directly. The documented surface:
- `client.beta.sessions.list()` — pagination works but **no `agent` filter param shown** in any language binding.
- `client.beta.sessions.retrieve(id)` — returns `{id, status}` in the examples. Statuses are `{idle, running, rescheduling, terminated}`. **No `lastActivityAt` field shown.**
- `client.beta.sessions.delete(id)` — confirmed, already used at `main.py:2113`. Running sessions need an interrupt event first.

Neither gap is a hard blocker — fallbacks exist (client-side filter; compute idle from events list or Service-1-maintained timestamp). But both must be spiked before committing to the design. Flagged as Q1 with a mandated Spike task that gates implementation. Lesson: when SDK docs don't show a field the brief assumes (e.g. `lastActivityAt`), do not silently map it to "probably exists" — force a spike.

## Idle-only vs absolute-age is a real design choice with cost implications

The brief locked idle-only. The temptation was to also add a 24h absolute ceiling "just in case". Resisted — a long-running demo session (account manager training) should not be killed just for being long. Idle is the correct signal. Documented the rejection in section 8 non-goals so reviewers don't re-litigate.

## Reuse existing patterns in the codebase, don't invent new ones

`main.py:2084-2128` already implements a full managed-session delete with 5s timeout. The new `stop_managed_session` function should be the extraction of that pattern, not a new implementation. Noted in handoff section 10 as a regression-test requirement (refactor existing path to call the new function). Pattern: when adding a module function, check if the behaviour already exists inline and refactor to the new function in the same PR.

## In-process scanner needs an explicit instance-count assumption

The scanner runs inside Service 1 as an asyncio task. Double-running on two Cloud Run instances is safe for deletes (idempotent) but duplicates warnings. Made the single-instance assumption explicit in section 4 with a mitigation path ("migrate dedup to Firestore if we scale out"). Don't leave operational assumptions implicit.

## Cite predecessor ADRs by filename, not by memory

Section 2.1 + section 10 both reference the session-state-encapsulation ADR (`2026-04-20-session-api-adr.md`). Cited the file path so Kayn doesn't have to hunt for it. Pattern continues from 2026-04-17-step2-service1-only-adr gotcha — amendment and dependency lists belong in the ADR body, not in task-decomposition.

## Blocker disclosure in the ADR, not just the report

Section 3's gap table + section 9's Q1 make the SDK-gap risk visible inside the ADR document itself, so anyone reading the plan later (not just the requester) sees the unresolved dependency. Reports to Sona are ephemeral; the ADR is the record.
