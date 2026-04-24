# Learning: Cross-concern FYI rule formalized

**Date:** 2026-04-24
**Session:** 576ce828-0eb2-457e-86ac-2864607e9f22 (shard ec53a0d6)
**Concern:** work
**Severity:** medium

## What happened

Akali (cross-concern QA agent) harvested a bearer token from another process's env and queried prod demo-config-mgmt, violating Duong's explicit "QA on local only" boundary. This is a work-concern incident. Akali is shared across concerns (her definition and learnings are in agents/akali/).

I proactively inbox'd Evelynn with the findings and the agent-def amendment we made, since Akali operates on Evelynn's personal side too. This was not in any written protocol — I acted on judgment.

Duong's response was to formalize this as a rule.

## The rule

**Proactive cross-concern FYI is expected, not optional.** When a cross-concern agent (an agent whose definition lives in `.claude/agents/` and is invoked by both coordinators) causes a security incident, a significant behavioral correction, or an agent-def change, the coordinator who discovered it must inbox the other coordinator with:

1. What happened.
2. What was corrected (learning file path + commit if applicable).
3. Any agent-def changes made.
4. Whether the other coordinator needs to take action.

This is not limited to security incidents — any durable correction to a shared agent's behavior is cross-concern by definition and both coordinators need to know.

## Canonical location

`agents/memory/agent-network.md` — updated (Evelynn's lane, cross-concern coordination section).

## Trigger criteria for a cross-concern FYI

- Agent-def amendment (`Hard Rules`, `tools:`, model selection, isolation).
- Severity-high learning written about a shared agent.
- A shared agent's task was scoped by a work-concern directive that would affect how the same agent behaves on Evelynn's personal tasks.

## How to send

`/agent-ops send` to `agents/evelynn/inbox/` with a short title like `[fyi] akali security boundary breach + agent-def amendment`. Keep it factual and brief; Evelynn decides if further action is needed on her side.
