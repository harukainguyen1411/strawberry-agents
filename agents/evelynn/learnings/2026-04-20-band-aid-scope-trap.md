# Band-aid scope trap — fix systemic before per-agent

**Date:** 2026-04-20
**Session:** S61

## The mistake

Lux failed three times to deliver her research — she kept closing with just `/end-subagent-session lux` instead of restating the report in her final message. My first fix: patch `lux.md`'s closeout section with explicit "your final message is all the parent sees" wording.

Duong caught it: *"Your fix is too literal, scoped to this incident. If you fixed the root cause, why do you need to fix their profile?"*

He was right. The rule — **background subagents' final message is all the parent sees** — applies to every single subagent in the roster, not just Lux. Swain, Jayce, Azir, and others happen to get it right because their closeout sections are more detailed, but the underlying constraint is systemic.

## The fix

Moved the rule to `agents/memory/agent-network.md` §Session Protocol as a universal "Final-message rule" subsection. Reverted Lux's closeout to the short form with a pointer to the shared rule. Commit: `e1f0f28`, then `c400aa7` to de-name "Evelynn" (Sona also dispatches).

## The pattern

When you see a failure:
1. Ask "does this failure mode apply only to this agent, or to any agent in similar circumstances?"
2. If the latter — patch the universal rule file (agent-network.md, CLAUDE.md, shared role rules), not the per-agent def.
3. Per-agent patches are correct only when the bug is genuinely agent-specific (e.g., Lux's stale `/strawberry/` startup path — that one was hers alone).

## Signal

"Your fix is too literal" / "scoped to this incident" from Duong = you treated a symptom. Stop. Zoom out. Find the universal rule.
