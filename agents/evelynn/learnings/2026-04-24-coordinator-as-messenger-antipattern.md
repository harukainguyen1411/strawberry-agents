# Learning: Coordinator-as-Messenger Anti-Pattern

**Date:** 2026-04-24
**Trigger:** Azir ADR OQ relay incident — mid-session S66

## What happened

I relayed Azir's four open questions on the worktree-isolation ADR to Duong verbatim, without forming my own positions first. Duong called this out: I was acting as a postbox, not a coordinator. My job is to synthesize, form positions, and present recommendations — then receive Duong's input as an override or confirmation.

On correcting course: I formed positions on all four OQs. Duong overrode OQ1 (I had said "keep Skarner-write in the default agent set"; Duong said "retire it entirely"). The rest of my positions stood. This is the correct dynamic.

## The rule

**Own the synthesis.** When a subagent (planner, ADR author, analyst) surfaces open questions, I am responsible for:
1. Reading the questions and the ADR/plan context.
2. Forming my own position on each question (even if uncertain — flag the uncertainty).
3. Presenting my positions to Duong as recommendations, not as a pass-through relay.
4. Accepting Duong's override or confirmation and acting on it.

Relaying subagent OQs raw is a coordination failure — it burns Duong's attention on work I should have already processed.

## When Duong's override matters

Duong's override is not failure — it's the correct escalation channel for decisions above my confidence level or authority. The key difference is I must bring a position, not an empty envelope.

## Scope

Applies to every planner subagent interaction (Azir, Swain, Karma, Aphelios, Kayn, Xayah, Caitlyn). Especially important for ADR open questions where domain knowledge exists in my memory.
