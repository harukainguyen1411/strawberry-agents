# Convenience tools must not become forcing functions

**Date:** 2026-04-26
**Source session:** 92718db2 (shard 15249699)
**Trigger:** Inbox-watcher PreToolUse hook had no `matcher` field, causing it to fire on every single tool call. Root plan authors: Azir (strawberry-inbox-channel, coordinator-boot-unification). The entire review chain — Orianna simplicity scan, Senna code review, Lucian fidelity review, Evelynn coordinator intake — failed to catch the design slip.

## The pattern

A convenience feature (inbox watch notification) was wired as a PreToolUse gate. When the gate misfired (missing `matcher`), it became pure friction: 4 hours of Sunday morning debugging, a cascade of false-positive blocks, and eventual removal of the entire hook infrastructure.

The root design error: a monitoring/notification feature was implemented as an enforcement hook. Monitoring tells you what happened. Enforcement gates whether something can happen. These are different threat models with different failure semantics. Enforcement hooks that fire incorrectly block work. Monitoring hooks that fire incorrectly produce noise.

## The heuristic

**Before wiring any feature as a PreToolUse gate, ask:** "What happens when this hook fires unexpectedly?" If the answer is "blocks the coordinator" — that feature does not belong in a PreToolUse hook unless it is genuinely a correctness constraint.

Convenience features (nice-to-have notifications, monitoring, status checks) belong in PostToolUse, Monitor tasks, or coordinator boot — never in PreToolUse gates.

## Review-chain implication

The full review chain failed here. Senna looks for correctness and security; Lucian checks plan fidelity; Orianna checks simplicity. None of these surfaces "is this the right hook type for this threat model?" That design-threat-model question is Evelynn's intake gate. File it: at coordinator intake, explicitly ask whether hook placement matches threat model.

## Filed artifacts

- `feedback/2026-04-26-convenience-promoted-to-forcing-function.md` — problem-only per Duong directive, no proposed solution
