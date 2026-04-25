# Synthesis before dual-advisory promotion

**Date:** 2026-04-25
**Session:** db2e8cdf (third Lissandra pre-compact consolidation)

## What happened

Lux and Swain both returned advisories on the Akali QA-discipline problem. Lux recommended tool-scope narrowing and a structured OBSERVE/Verdict/SIGNAL/Read-trail report format. Swain recommended a two-agent architecture (Akali observe → Senna diagnose) with a citation-tagging contract. Both plans landed in `plans/proposed/`. Neither was promoted because:

1. The framing that triggered the escalation (Sona's "Akali fabricates") was retracted mid-flight.
2. The two advisory outputs touch the same PostToolUse hook surface as the Lux monitoring research (dashboard events and Akali reminder hooks may need to be designed as one wiring, not two patches).
3. The correct next step is coordinator synthesis, not sequential promotion.

## The pattern

When two advisory agents return findings on the same system surface within the same session, the coordinator's job is synthesis — form a unified position, identify the shared constraints, then promote one coherent plan. Promoting both sequentially without synthesis produces two plans with overlapping assumptions and contradictory implementation surface allocations. The resulting conflict surfaces at implementation time (Talon gets two conflicting plans for the same hook).

## The rule

Before promoting any plan from a dual-advisory cycle: read both, identify the shared surface, write one coordinator position (even if just a mental note), then either (a) synthesize into a single revised plan, (b) sequence them explicitly (tactical-first, structural-second with a declared dependency), or (c) surface the conflict to Duong with a position. Do not relay raw OQs from each advisor independently — that is coordination failure, not coordination.

## Related

- `2026-04-24-coordinator-as-messenger-antipattern.md` — covers raw-OQ relay generally.
- This learning is specifically about the dual-advisory synthesis gap.
